# DiaNN
AWS/Ronin big machine (windows) and multinode (linux) instructions to run https://github.com/vdemichev/DiaNN

# Set up on Ronin Windows
* Make a machine. You probably want the flavours starting with C (compute), R (memory), or M (also good). You want to use the biggest number (i.e. the most recent generation of flavours, at least 5, maybe 6 or 7). You probably only want to use flavours with no other letters following the number, execpt A (AMD instead of the default Intel) - these are cheaper and possibly faster. So to start with pick "C5.LARGE" - we will change this to "C5.24XLARGE" once we have everything set up and are ready to spend the big bucks.
* Change password (because of a weird windows bug, where setting the initial password does nothing).
* Connect to Machine with RDP.
* Allow downloads: https://sydneyuni.atlassian.net/wiki/spaces/RC/pages/1171423886/Tips+and+tricks+and+hacks
* Download Firefox (or similar)
* Download WinSCP (or similar)
* Mount external drive: https://blog.ronin.cloud/make-storage-available-windows/
* Copy data over using RDS ftp connection at research-data.ext.sydney.edu.au
BUT! research-data-ext is unfortunately very flakey, so we may have to "push" data to the server rather than "pull" data from the RDS, to do that:
* Allow sftp to windows: https://winscp.net/eng/docs/guide_windows_openssh_server#installing_sftp_ssh_server
* Copy data over e.g.:
```
ssh hpc.sydney.edu.au
cd /rds/PRJ-NASHplasma/WD_EXP1/Expanded Wiff/
sftp Administrator@<yourmachinename>.SYDNEYUNI.CLOUD
cd /D:/
mkdir Expanded_Wiff
put *
```
Another even better way is to mount a drive on a linux machine, then just rsync so you don't have to use sftp between linux and windows. Then detach and go!
Once the data is on the drive and within the Ronin ecosystem and off RDS (approx 10 hours per TB), you may snapshot it, detach it, re-attach it to other instances, etc!
Now:
* Donwload Diann: https://github.com/vdemichev/DiaNN#installation
* Download Protowizard: https://proteowizard.sourceforge.io/download.html
* Install Diann:
*For .wiff support, download and install ProteoWizard - choose the version (64-bit) that supports "vendor files"). Then copy all files with 'Clearcore' or 'Sciex' in their name (these will be .dll files) from the ProteoWizard folder to the DIA-NN installation folder (the one which contains diann.exe, DIA-NN.exe and a bunch of other files).*
* Run DIANN! Or before this point, you may want to shut off the machine and renofigure the instance type, then run it!

Done!

# Set up on Ronin Linux Auto-Scale Cluster

Make the machine and connect to it. Choose a flavour (probably C5 or M5 series are probably good with enough RAM and CPU).

Setup singularity
```
spack install singularity
sudo su
bash /apps/spack/opt/spack/linux-ubuntu18.04-skylake_avx512/gcc-7.5.0/singularity-3.8.5-uy6ax3f5654sn76me3ykamfi2x5l2m3t/bin/spack_perms_fix.sh
```

Pull the ```diann``` and ```msconvert``` images:
```
spack load singularity
cd /apps
singularity pull docker://biocontainers/diann:v1.8.1_cv1
singularity pull docker://chambm/pwiz-skyline-i-agree-to-the-vendor-licenses
```

Install gnu-parallel into /apps
```
wget https://ftpmirror.gnu.org/parallel/parallel-latest.tar.bz2
tar -xvjf parallel-latest.tar.bz2
cd parallel
./configure --prefix /apps
make
make install
```

Mount an additional exfat drive to the cluster
```
sudo apt update -y
sudo apt-get -y install exfat-fuse exfat-utils
sudo mkdir /mnt/data
lsblk #To find where the partition is located, in my case nve3n1p2
sudo mount  -t exfat /dev/nvme3n1p2 /mnt/data
```

Setup the Mass Spec files for reading and the output folders and copy data to the cluster, e.g.
```
mkdir /shared/WD_EXP1
mkdir /shared/out

scp -i ~/.ssh/dkey.pem sp_human_160321.fasta ubuntu@dianncluster.sydneyuni.cloud:/shared/sp_human_160321.fasta
scp -i ~/.ssh/dkey.pem  *.wiff ubuntu@dianncluster.sydneyuni.cloud:/shared/WD_EXP1/
```

You should also checksum the data to make sure nothing was lost in the transfer. e.g.
```
md5sum WD_EXP1/Expanded\ WIFF/* > md5sums.txt
scp -i ~/.ssh/dkey.pem   md5sums.txt ubuntu@dianncluster.sydneyuni.cloud:/shared/WD_EXP1/
md5sum -c md5sums.txt
```


## Convert .wiff to .mzML as required on Linux DiaNN

The ```msconvert``` utility is required to make files that are readable on Linux [https://github.com/vdemichev/DiaNN#raw-data-formats](https://github.com/vdemichev/DiaNN#raw-data-formats)

Make a slurm script to convert .wiff to .mzML, ```run_msconvert.sh```
```
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=96

spack load singularity

cd /shared/DATA/
ls -d /shared/DATA/*.wiff | /apps/bin/parallel --jobs 0 \
        /usr/bin/time -v singularity run --fakeroot --env WINEDEBUG=-all -B /shared/:/shared/ \
        /apps/pwiz-skyline-i-agree-to-the-vendor-licenses_latest.sif \
        wine msconvert {} --32 --filter "peakPicking vendor msLevel=1-" -o /shared/WD_EXP1/  --outfile {.}.mzML
```

Execute with 
```
sbatch run_msconvert.sh
```

Or, because I had the data on a mounted drive not easily visible by the compute nodes, I just ran it on the head node like so. Firstly, make a file with all the gnu parallel commands:
```
cd /mnt/data/Expanded_WIFF

for i in `ls -d *.wiff`; 
        do echo '/usr/bin/time -v singularity run --fakeroot --env WINEDEBUG=-all -B /shared/:/shared/ -B /apps:/apps -B/mnt/data:/mnt/data \
        /apps/pwiz-skyline-i-agree-to-the-vendor-licenses_latest.sif wine msconvert \
        '"$PWD"/${i}' --32 --filter "peakPicking vendor msLevel=1-" -o /shared/WD_EXP1/ --outfile '${i%%.*}'.mzML'; 
        done > /shared/commands.txt
```
And run them in a tmux session:
```
cd /shared/
tmux
parallel < commands.txt
cntrl+b d
```
Keep in mind this uses around 4GB of storage per process in a tmp file (defaulted to the root drive /tmp/root-fs). Be wary not to fill your drive. This takes around 1 hour per file per cpu.

You can get a list of the currently running sessions using `tmux list-sessions` or simply `tmux ls`, now attach to a running session with command `tmux attach-session -t <session-name>`.




## Run diann

Create a config file with *most* of the DiaNN options, call it ```diann.cfg``` or whatever.

>```--lib --threads 96 --verbose 1  --qvalue 0.01 --matrices --gen-spec-lib --predictor --prosit --fasta-search --min-fr-mz 150 --max-fr-mz 1500 --met-excision --cut K*,R* --missed-cleavages 1 --min-pep-len 7 --max-pep-len 30 --min-pr-mz 400 --max-pr-mz 900 --min-pr-charge 1 --max-pr-charge 4 --unimod4 --var-mods 1 --var-mod UniMod:1,42.010565,*n --monitor-mod UniMod:1 --double-search --reanalyse --smart-profiling --peak-center```

We want to batch the work into reasonable chunks, some discussion or thought could go further into this, but my approach was to simply split into 4 batches of about 80 files each based on experiment index. A better way may be to randomly subset into however many nodes you want to run on. Nevertheless, we must list these data in a file which we will pass to `diann` to read:
```
for i in 061221_WD_EXP1_1_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_1.txt
for i in 061221_WD_EXP1_2_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_2.txt
for i in 061221_WD_EXP1_3_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_3.txt
for i in 061221_WD_EXP1_4_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_4.txt
```

Make a slurm script to run diann, ```run_diann.sh```

```
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=96
#Assume there are 96 CPUS availble per node. Adjust as needed

spack load singularity

/usr/bin/time -v singularity run --bind /shared:/shared --bind /apps:/apps /apps/diann_v1.8.1_cv1.sif /bin/bash -c \
        "diann `cat /apps/scripts/dconfig.txt` \
        --fasta /shared/sp_human_160321.fasta \
        `cat /apps/scripts/dinput_${SLURM_ARRAY_TASK_ID}.txt` \
        --out /shared/out/Library_Free_Search_SP_HUMAN_061221_WD_EXP1_${SLURM_ARRAY_TASK_ID}.tsv \
        --out-lib /shared/out/Library_Free_Search_SP_HUMAN_LIB_061221_WD_EXP1_${SLURM_ARRAY_TASK_ID}.tsv"
```

Execute with:
```
sbatch -a [1-4] run_diann.sh
```

## Combine the output files from each of the batches

```
head -1 Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_1.tsv > results.tsv
head -1 Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_1.stats.tsv > results.stats.tsv

for i in Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_?.stats.tsv; do tail -n +2 $i >> results.stats.tsv; done
for i in Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_?.tsv; do tail -n +2 $i >> results.tsv; done
```

Generate a report (not sure if this tool is avaible on Linux, but in Windows e.g:
```
C:\DIA-NN\1.8.1> dia-nn-plotter.exe C:\WORK\Projects\diann\results.stats.tsv C:\WORK\Projects\diann\results.tsv C:\WORK\Projects\diann\res.pdf
```


# Gadi

Assuming you are working in `/scratch/md01/DIANN`

## Set up data dir

/scratch/md01/DIANN

run_diann.pbs
run_msconvert.pbs
convert.sh
diann_v1.8.1_cv1.sif
sp_human_160321.fasta
Expanded_WIFF
pwiz.sif

## Convert the .wiff files to .mzML
We will use nci-parallel to convert all the files. Run the convert.sh which reads all the input files in Expanded_WIFF to create the commands to individually convert each of the .wiff files to .mzML

```
mkdir Expanded_mzML
for i in `ls -d Expanded_WIFF/*.wiff`;
        do echo 'singularity run --env WINEDEBUG=-all -B /scratch/:/scratch /scratch/md01/DIANN/pwiz.sif wine msconvert '"$PWD"/${i}' --32 --filter "peakPicking vendor msLevel=1-" -o /scratch/md01/DIANN/Expanded_mzML/ --outfile '${i%%.*}'.mzML';
done > commands.txt
```

In theory this should then be as easy as:
```
qsub run_msconvert.pbs
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

But there are some issues with the singularity container. Specifically the wine folder is owned by 'root' and you cannot run singularity with `--fakeroot` on Gadi. To overcome this I did a hack to rebuild the container. See this stack overflow question for some more details `https://stackoverflow.com/questions/73328706/running-singularity-container-without-root-as-different-user-inside`.
NCI help also suggested the following:

```
ORIGINAL_PREFIX=${WINEPREFIX}
WINEPREFIX=$(mktemp -d wineprefix)
export WINEPREFIX

for file in ${ORIGINAL_PREFIX}/*
do
  ln -sT ${file} ${WINEPREFIX}/$(basename ${file})
done
```

This step should take around 2 hr 15 min with 288 cpus to convert 322 files. 370 CPU hours.


## Make configuration files

Depending on how you partition the files into batches this may change. e.g. we used a simpler method for RONIN steps above. Here we are batching them in 14 batches grouped by a consistent number of files (23 per batch).

```
ls -v Expanded_mzML/ | head -n 23 > dinput_1.list
ls -v Expanded_mzML/ | tail -n +24 | head -n 23 > dinput_2.list
ls -v Expanded_mzML/ | tail -n +47 | head -n 23 > dinput_3.list
ls -v Expanded_mzML/ | tail -n +70 | head -n 23 > dinput_4.list
ls -v Expanded_mzML/ | tail -n +93 | head -n 23 > dinput_5.list
ls -v Expanded_mzML/ | tail -n +116 | head -n 23 > dinput_6.list
ls -v Expanded_mzML/ | tail -n +139 | head -n 23 > dinput_7.list
ls -v Expanded_mzML/ | tail -n +162 | head -n 23 > dinput_8.list
ls -v Expanded_mzML/ | tail -n +185 | head -n 23 > dinput_9.list
ls -v Expanded_mzML/ | tail -n +208 | head -n 23 > dinput_10.list
ls -v Expanded_mzML/ | tail -n +231 | head -n 23 > dinput_11.list
ls -v Expanded_mzML/ | tail -n +254 | head -n 23 > dinput_12.list
ls -v Expanded_mzML/ | tail -n +277 | head -n 23 > dinput_13.list
ls -v Expanded_mzML/ | tail -n +300 | head -n 23 > dinput_14.list

for i in {1..14}; do sed -e 's#^#--f /scratch/md01/DIANN/Expanded_mzML/#' dinput_${i}.list > /scratch/md01/DIANN/scripts/dinput_${i}.txt; done
cd scripts
for i in {1..14}; do sed -i '1i--use-quant' dinput_${i}.txt; done
for i in {1..14}; do sed -i 's#$# \\#'  dinput_${i}.txt; done
```

## Run DiaNN

Unlike Slurm on Ronin, Gadi does not have arrays, so we can pass the script name on the command line to use as a variable as
```
qsub -N <1-14> run_diann.pbs
```

```
#!/bin/bash

#PBS -q normal
#PBS -l ncpus=48
#PBS -l walltime=24:00:00
#PBS -l mem=190GB
#PBS -l wd
#PBS -l storage=scratch/md01
#PBS -P md01
module load singularity
export PROJFOLDER=/scratch/md01/DIANN
mkdir -p ${PROJFOLDER}/out
/usr/bin/time -v singularity run --bind /scratch:/scratch ${PROJFOLDER}/diann_v1.8.1_cv1.sif /bin/bash -c \
        "diann `cat ${PROJFOLDER}/scripts/dconfig.txt` \
        --fasta ${PROJFOLDER}/sp_human_160321.fasta \
        `cat ${PROJFOLDER}/scripts/dinput_${PBS_JOBNAME}.txt` \
        --out ${PROJFOLDER}/out/Library_Free_Search_SP_HUMAN_061221_WD_EXP1_${PBS_JOBNAME}.tsv \
        --out-lib ${PROJFOLDER}/out/Library_Free_Search_SP_HUMAN_LIB_061221_WD_EXP1_${PBS_JOBNAME}.tsv"
```
