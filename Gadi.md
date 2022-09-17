# DiaNN on NCI Gadi

Assuming you are working in `/scratch/md01/DIANN`.

## 1. Set up data dir

Contents of `/scratch/md01/DIANN`:

Singularity containers:
```
diann_v1.8.1_cv1.sif
pwiz.sif
```

fasta data file and folder containing all sequential `.wiff` and accompanying `.scan` files that will be analysed.
```
sp_human_160321.fasta
Expanded_WIFF
```

Scripts for running workflows:
```
run_STEP1.pbs
run_STEP2.pbs
run_STEP3.pbs
run_STEP4.pbs
run_STEP5.pbs
generate_commands.sh
run_msconvert.pbs
convert.sh
```


## 2. Convert the .wiff files to .mzML

We will use `nci-parallel` to convert all the files in parallel. Run the `convert.sh` script which reads all the input files in the `Expanded_WIFF` directory to create the commands read by `nci-parallel` to convert each of the `.wiff` files to `.mzML`. The script looks something like this, change hardcoded directories as needed:

```
mkdir Expanded_mzML
for i in `ls -d Expanded_WIFF/*.wiff`;
        do echo 'singularity run --env WINEDEBUG=-all -B /scratch/:/scratch /scratch/md01/DIANN/pwiz.sif wine msconvert '"$PWD"/${i}' --32 --filter "peakPicking vendor msLevel=1-" -o /scratch/md01/DIANN/Expanded_mzML/ --outfile '${i%%.*}'.mzML';
done > commands.txt
```

This pbs file using nci-parallel (a special implimentation of gnu-parallel) reads from the `commands.txt` file created above. Adjust as needed.
```
#!/bin/bash
#PBS -q normal
#PBS -l ncpus=288
#PBS -l walltime=04:00:00
#PBS -l mem=190GB
#PBS -l wd
#PBS -l storage=scratch/md01
#PBS -P md01

module load nci-parallel/1.0.0a
export ncores_per_task=1
export ncores_per_numanode=12

module load singularity
pwd
mkdir -p /scratch/md01/DIANN/tmp
mkdir -p /scratch/md01/DIANN/cache
export SINGULARITY_TMPDIR=/scratch/md01/DIANN/tmp
export SINGULARITY_CACHEDIR=/scratch/md01/DIANN/cache
mpirun -np $((PBS_NCPUS/ncores_per_task)) --map-by ppr:$((ncores_per_numanode/ncores_per_task)):NUMA:PE=${ncores_per_task} nci-parallel --input-file /scratch/md01/DIANN/commands.txt --timeout 10000
```

Submit to the queue.
```
qsub run_msconvert.pbs
```

Converstion should take between 1-2 hours per file per cpu. Using 288 cpus to convert 322 files took a walltime of 2 hr 15 min (or 370 CPU hours).


Note: there were some issues with the singularity container. Specifically the `wine` folder is owned by 'root' and you cannot run singularity with `--fakeroot` on Gadi. To overcome this I did a hack to rebuild the container. See this stack overflow question for some more details `https://stackoverflow.com/questions/73328706/running-singularity-container-without-root-as-different-user-inside`.
NCI help also suggested the following I have yet to try (because there are a looooot of files that need linking):

```
ORIGINAL_PREFIX=${WINEPREFIX}
WINEPREFIX=$(mktemp -d wineprefix)
export WINEPREFIX

for file in ${ORIGINAL_PREFIX}/*
do
  ln -sT ${file} ${WINEPREFIX}/$(basename ${file})
done
```



## 3. Make list of files to be read in STEP3 and STEP5

```
#Group the filenames into batches
ls -v Expanded_mzML/ > filelist.list

#Add "--f" to the start of each line and push to the actual config files
sed -e 's#^#--f /scratch/md01/DIANN/Expanded_mzML/#' filelist.list > /scratch/md01/DIANN/scripts/filelist.txt; done

#Add "\" to the end of each line
sed -i 's#$# \\#'  /scratch/md01/DIANN/scripts/filelist.txt
```

Adjust the DiaNN configuration option in each run_STEP?.pbs as appropriate for your experiment.

## 4. Run DiaNN Workflow

### run_STEP1.pbs

```
#!/bin/bash
#PBS -q normal
#PBS -l ncpus=48
#PBS -l walltime=48:00:00
#PBS -l mem=190GB
#PBS -l wd
#PBS -l storage=scratch/md01
#PBS -P md01
#PBS -j oe
#PBS -N par_STEP1


module load singularity

export PROJFOLDER=/scratch/md01/DIANN
export FASTAFILE=${PROJFOLDER}/sp_human_160321.fasta
export OUTDIR=${PROJFOLDER}/out_par
mkdir -p ${OUTDIR}
export NTHREADS=$(expr ${PBS_NCPUS} + ${PBS_NCPUS})
export NTHREADS=24

/usr/bin/time -v singularity run --bind /scratch:/scratch ${PROJFOLDER}/diann_v1.8.1_cv1.sif /bin/bash -c \
        "diann --cut K*,R*,!*P --fixed-mod Carbamidomethyl,57.021464,C --var-mod Oxidation,15.994915,M \
        --fasta-search --min-pr-mz 350 --max-pr-mz 950 --min-fr-mz 150 --max-fr-mz 1500 --min-pep-len 7 --max-pep-len 30 \
        --min-pr-charge 2 --max-pr-charge 3 --var-mods 2  --predictor --verbose 3 --gen-spec-lib --missed-cleavages 1 \
        --threads ${NTHREADS} --fasta ${FASTAFILE} \
        --out ${OUTDIR}/report_${PBS_JOBNAME}.tsv --out-lib  ${OUTDIR}/lib_${PBS_JOBNAME}.lib"
```
Submit with ```job1=`qsub run_STEP1.pbs````

### run_STEP2.pbs

```
#!/bin/bash

#PBS -q normal
#PBS -l ncpus=288
#PBS -l walltime=12:00:00
#PBS -l mem=190GB
#PBS -l wd
#PBS -l storage=scratch/md01
#PBS -P md01
#PBS -j oe
#PBS -N par_STEP2

module load nci-parallel/1.0.0a
module load singularity

export ncores_per_task=6
export ncores_per_numanode=12
export PROJFOLDER=/scratch/md01/DIANN

mpirun -np $((PBS_NCPUS/ncores_per_task)) --map-by ppr:$((ncores_per_numanode/ncores_per_task)):NUMA:PE=${ncores_per_task} \
  nci-parallel --input-file ${PROJFOLDER}/commands_STEP2.txt --timeout 10000
```
Submit with ```qsub -W depend=afterok:${job1} run_STEP1.pbs```





