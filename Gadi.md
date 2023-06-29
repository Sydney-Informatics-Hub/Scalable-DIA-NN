# DiaNN on NCI Gadi

<p align="center">
:wrench: This pipeline is currently under development :wrench:
</p>

- [Description](#description)
- [Set up & installation](#set-up--installation)
- [Required inputs](#required-inputs)
    - [Converting wiff to mzML](#converting-wiff-to-mzml)
- [User guide](#user-guide)
    - [Step 1. Generate insilico spectral library](#step-1-generate-insilico-spectral-library)
    - [Step 2. Preliminary analysis (scalable)](#step-2-preliminary-analysis-scalable)
    - [Step 3. Assemble empirical spectral library](#step-3-assemble-empirical-spectral-library)
    - [Step 4. Individual file analysis (scalable)](#step-4-individual-file-analysis-scalable)
    - [Step 5. Summarise](#step-5-summarise)
- [Benchmarks](#benchmarks)

## Description

This workflow implements the Linux/CLI installation of [DIA-NN](https://github.com/vdemichev/DiaNN) in a highly scalable fashion on the [National Computational Infrastructure's Gadi HPC](https://nci.org.au/news-events/events/introduction-gadi-4#:~:text=Gadi%20is%20Australia's%20most%20powerful,designing%20molecules%20to%20astrophysical%20modelling). DIA-NN is a tool that performs data processing and analysis for data-independant acquistion (DIA) proteomics data and was originally developed by Demichev, Ralser and Lilley Labs ([Ralser et al. 2020](https://www.nature.com/articles/s41592-019-0638-x)).

## Set up & installation

You must have a project and allocation on NCI Gadi to run this workflow. Once you have logged onto Gadi, navigate to your working directory, e.g: 

```
cd /scratch/xh27/tc6463
```

Clone this repository and change into the `Gadi` directory:

```
git clone https://github.com/Sydney-Informatics-Hub/DiaNN.git
cd Gadi
```

`pwd` should resemble the path `/scratch/xh27/tc6463/Gadi`. **All scripts and containers should be in this directory. Run all commands and scripts here.**

This workflow uses singularity to execute tools required for this workflow. Pull the DIA-NN singularity container from the biocontainers repository:

```
module load singularity
singularity pull docker://biocontainers/diann:v1.8.1_cv1
```

You should now have the singularity container `diann_v1.8.1_cv1.sif` and the `*.pbs`, `*.sh` scripts to run this workflow on Gadi. 

## Required inputs 

### Proteome FASTA

Transfer your Uniprot formatted FASTA file to the working directory, e.g. `/scratch/xh27/tc6463/Gadi`

### Prepare mzML input data

The Linux version of DIA-NN supports `*.mzML` file formats. All `*.mzML` data should be transferred to a directory within `Gadi`, e.g. `/scratch/xh27/tc6463/Gadi/Expanded_mzML`. Sciex `*.wiff` data must be converted to `*.mzML` format (see below). 

#### Converting wiff to mzML with ProteoWizard

[DIA-NN recommends ProteoWizard](https://github.com/vdemichev/DiaNN#raw-data-formats) for `*.wiff` file support. There were some issues with this singularity container. Specifically the `wine` folder is owned by 'root' and you cannot run singularity with `--fakeroot` on Gadi. You will need to rebuild the container for your user ID on Gadi on a compute your have sudo access to (e.g. your laptop). Annoyingly, **this must be done uniquely for every user**. See this stack overflow question for some more details `https://stackoverflow.com/questions/73328706/running-singularity-container-without-root-as-different-user-inside`.

Save the below as singularity recipe file called `pwiz.build` (this has very minimal changes from the original docker file):

Run `id -u `whoami`` on Gadi. Replace <uid> and <username> with your Gadi UID and username in `pwiz.build`. 

```
Bootstrap: docker
From: chambm/pwiz-skyline-i-agree-to-the-vendor-licenses
%post

#Get uid from "id -u `whoami`" on Gadi
useradd -u <uid> <username>
chown -Rf --no-preserve-root <username> /wineprefix64
```

Built on a local machine with:
```
sudo singularity build pwiz.sif pwiz.build
```

You will then need to transfer this container to your working directory on Gadi, e.g. `/scratch/xh27/tc6463/Gadi`.

##### Convert files

1. Make inputs 

Open `convert_make_input.sh` in an text editor and change variables:

- `pwiz=pwiz.sif`. Full or relative path to the ProteoWizard singularity container.
- `wiffDir=wiff`. Full or relative path to the directory containing your wiff files to convert.
- `outDir=Expanded_mzML`. Full or relative path to the output directory containing convered mzML files.

Save and run the script by `sh convert_make_input.sh`. This will create `Inputs/convert.txt` which should resemble:

```
[tc6463@gadi-login-06 DiaNN_dev]$ head Inputs/convert.txt
pwiz.sif,pilot_data/Sample1.wiff,Expanded_mzML,./Logs/convert
pwiz.sif,pilot_data/Sample2.wiff,Expanded_mzML,./Logs/convert
pwiz.sif,pilot_data/Sample3.wiff,Expanded_mzML,./Logs/convert
```

Each line of this file will be provided as input to `convert.sh`.

2. Check command to be executed in parallel

Check `convert.sh` which contains the command to convert one wiff to one mzML file.

3. Execute commands in parallel, with each command taking one line of input data

Open `convert.pbs` in a text editor and edit the PBS directives, scaling compute to the number of files you need to convert. Allow 1 CPU, 4GB MEM, walltime=02:00:00 per file conversion for [Gadi's normal queue](https://opus.nci.org.au/display/Help/Queue+Limits). This uses `nci-parallel` to execute `convert.sh` for every line of input in `Inputs/convert.txt`. Submit the job by:

```
qsub convert_run_parallel.pbs
```

4. Perform checks

To check that the job completed successfully:
- Check Gadi job log files `Logs/convert.e` (all tasks should have exit status of 0 and match the number of lines in `Inputs/convert.txt`) and `Logs/convert.o` 
- Check the expected output exists. In this example, this would be the `Example_mzML/*.mzML` files.
- Check task log files in the directory `Logs/convert` - especially if you suspect some tasks failed (from checks above).

## User guide

Submit all scripts from the Gadi directory, e.g. `/scratch/xh27/tc6463/Gadi`. Each step includes 1 job submitted to Gadi. Only proceed with the next step once the previous step has completed successfully. 

**General note (more details are provided in the steps below):** Some steps in the workflow are scalable. For these steps, input parameters are generated with `*_make_input.sh` and saved into a file such as `Inputs/inputs.txt`. Each line of `inputs.txt` will be used by a command script such as `commands.sh` and run as an independant "task". Thus, the `commands.sh` is where you would adjust parameters for all tasks. To run `commands.sh` in parallel with `inputs.txt`, use `command.pbs`, scaling compute to the number/size of inputs you have. 

### Step 1. Generate insilico spectral library

Description: Generate an in silico predicted spectral library from a FASTA sequence database (in Uniprot format).

Required inputs: Uniprot formatted FASTA file, e.g. `mouse_proteome.fasta`

Check/edit `1_generate_insilico_lib.pbs`:
* The default PBS directives are sufficient for a human/mouse reference FASTA sequence file.
* `fasta=mouse_proteome.fasta`. Change to the full or relative path to your reference FASTA file.
* `diannImg=diann_v1.8.1_cv1.sif`. Full or relative path to diann singularity container.
* Check/change parameters. The current settings follow [quantms defaults](https://github.com/bigbio/quantms).

Submit the job by:

```
qsub 1_generate_insilico_lib.pbs
```

### Step 2. Preliminary analysis (scalable)

Description: Analyse each run (ie mzML file) with the in silico library generated in step 1. The mass accuracies and the scan window settings in DIA-NN should be either fixed or left automatic. In the latter case, please use `--individual-mass-acc` and `--individual-windows`. If mass accuracies are automatic, please also supply the `--quick-mass-acc` command. Specify a folder with `--temp` where `.quant` files will be saved to.

Required inputs: `*.predicted.speclib`, sample `*.mzML` files

Check/edit variables in `2_preliminary_analysis_make_input.sh`:
* `diannImg=diann_v1.8.1_cv1.sif`. Full or relative path to diann singularity container. 
* `lib=mouse_proteome.predicted.speclib`. Full or relative path to in silico spectral library produced in step 1.
* `mzMLDir=Expanded_mzML`. Full or relative path to the directory containing sample mzML files

Run the script: 

```
sh 2_preliminary_analysis_make_input.sh
```

This will generate `Inputs/2_preliminary_analysis.txt`, containing a list of inputs for `2_preliminary_analysis.sh`.

Check/edit parameters in `2_preliminary_analysis.sh`, containing the diann command to run. 

* The script is currently set to "automatic"
* From [the DIA-NN primary developer](https://github.com/bigbio/quantms/issues/164): "Low RAM & high speed mode enabled by --min-corr 2.0 --corr-diff 1.0 --time-corr-only might prove useful during Step 2, it typically leads to no or very minimal drop in ID numbers."
* If you made changes to the command, I recommend checking that it works before executing it on all samples by copying the first line of `Inputs/2_preliminary_analysis.txt` and on the command line:

```
# Optional check
module load singularity
NCPUS=1
sh 2_preliminary_analysis.sh <first line of Inputs/2_preliminary_analysis.txt>
```

Edit `2_preliminary_analysis.pbs`

* The PBS directives: scale compute using `#PBS -l` directives to the number of mzML files and allow for additional walltime. From benchmarking, allow 8 CPU, 16GB MEM, walltime=00:19:04 per mzML file. Edit `#PBS -l storage=` and `#PBS -P project` directives.

Run the job:
```
qsub 2_preliminary_analysis.pbs
```

### Step 3. Assemble empirical spectral library

Description: Assemble and empirical spectral library from sample `*.quant` files generated with the predicted spectral library in steps 1 & 2. 

Required inputs: sample `*mzML` files, used to locate sample quant files in `--temp` directory `quant/*.quant`, `*.predicted.speclib`

Check/edit `3_assemble_empirical_lib.pbs`:
* The PBS directives: Compute should be sufficient to process ~100 samples. Time sigificantly increases without previously generated `*.quant` files. Scalability testing is required to understand how this job handles more samples. Edit `#PBS -l storage=` and `#PBS -P project` directives. 

Run the job:
```
qsub 3_assemble_empirical_lib.pbs
```

### Step 4. Individual file analysis (scalable)

Description: Final analysis of individual raw files using empirical spectral library with each individual raw file (in parallel). 

Check/edit variables in `4_individual_final_analysis_make_input.sh`:
* `diannImg=diann_v1.8.1_cv1.sif`. Full or relative path to diann singularity container.
* `lib=mouse_proteome.empirical.speclib`. Full or relative path to `*.empirical.speclib`.
* `mzMLDir=Expanded_mzML`. Full or relative path to directory containing `*.mzML` (used to locate sample `*.quant` files in the `quant` directory)

Run the script:
```
sh 4_individual_final_analysis_make_input.sh
```

This will generate `Inputs/4_individual_final_analysis.txt`, containing a list of inputs for `4_individual_final_analysis.sh`.

Check/edit parameters in `4_individual_final_analysis.sh`, containing the diann command to run. 

* [Please note the developers comment](https://github.com/bigbio/quantms/issues/164): Now, mass accuracies & scan window must be fixed here. If mass accuracise and scan windows were not fixed for Step 2, in the log file produced by the Step 3, there's a line like "Averaged recommended settings for this experiment: Mass accuracy = 11ppm, MS1 accuracy = 15ppm, Scan window = 7". From step 3's `report.log.txt`, you'll find something like:

```
[0:09] Averaged recommended settings for this experiment: Mass accuracy = 11ppm, MS1 accuracy = 20ppm, Scan window = 8
```
* If you made changes to the command, I recommend checking that it works before executing it on all samples by copying the first line of `Inputs/4_individual_final_analysis.txt` and on the command line:

```
# Optional check
module load singularity
NCPUS=1
sh 4_individual_final_analysis.sh <first line of Inputs/4_individual_final_analysis.txt>
```

Check/edit `4_individual_final_analysis.pbs`:
* The PBS directives: Compute should be sufficient to process ~100 samples (although more benchmarking and scalability testing is required). Edit `#PBS -l storage=` and `#PBS -P project` directives. 

Submit the job:
```
qsub 4_individual_final_analysis.pbs
```

### Step 5. Summarise

Summarise the analysis 

Required inputs: `empirical_library.tsv.speclib`, `*.fasta` (for annotation), sample `*.mzML` files (to locate `quant/*quant` files generated in step 4)

Check/edit variables in `5_summarise.pbs`:
* PBS directives: Edit `#PBS -l storage=` and `#PBS -P project` directives. Compute is small, for ~100 mouse samples allow `ncpus=1`, `mem=16GB`, `walltime=00:10:00`. For more samples, I recommend increasing memory (scalability tests to be performed).
* Edit variables:
    * `diannImg=diann_v1.8.1_cv1.sif`. Full or relative path to diann singularity container.
    * `fasta=mouse_proteome.fasta`. Full or relative path to your reference FASTA sequence file.
    * `empirical_lib=mouse_proteome.empirical.speclib`. Full or relative path to the empirical spectral library generated at step 3.
    * `mzMLDir=Expanded_mzML`. Full or relative path to the directory containing sample `*mzML` files, used to locate `*.quant` files generated in step 4.


## Benchmarks

To process 105 mouse mzML files:

```
#JobName        CPUs_requested  CPUs_used       Mem_requested   Mem_used        CPUtime CPUtime_mins    Walltime_req    Walltime_used   Walltime_mins   JobFS_req       JobFS_used      Efficiency      Service_units   Job_exit_status Date    Time
1_gen_insilico_lib.o    8       8       32.0GB  12.73GB 02:34:43        154.72  48:00:00        00:22:53        22.88   100.0MB 0B      0.85    6.10    0       2023-01-19      16:14:55
2_preliminary_analysis.o        480     480     1.86TB  1.15TB  164:09:52       9849.87 04:00:00        00:44:19        44.32   1000.0MB        8.18MB  0.46    709.07  0       2023-01-20      17:24:23
3_gen_empirical_lib.o   12      12      32.0GB  10.63GB 00:02:08        2.13    05:00:00        00:01:51        1.85    100.0MB 0B      0.10    0.74    0       2023-01-20      16:11:33
4_individual_final_analysis.o   480     480     1.86TB  767.57GB        15:08:59        908.98  04:00:00        00:05:03        5.05    1000.0MB        8.18MB  0.37    80.80   0       2023-01-20      16:32:52
5_summarise.o   12      12      32.0GB  4.24GB  00:01:57        1.95    05:00:00        00:02:11        2.18    100.0MB 0B      0.07    0.87    0       2023-01-20      16:47:08
convert.o       144     144     570.0GB 362.21GB        111:08:14       6668.23 04:00:00        01:50:31        110.52  300.0MB 8.17MB  0.42    530.48  0       2023-01-20      10:58:06
convert_normalbw.o      112     112     512.0GB 165.39GB        136:21:48       8181.80 04:00:00        02:35:22        155.37  400.0MB 8.1MB   0.47    362.52  0       2023-01-19      15:17:06
```
