# Scalable DIA-NN 

### Overview

This workflow implements the CLI installation of [DIA-NN](https://github.com/vdemichev/DiaNN) in a highly scalable fashion. DIA-NN is a popular tool that performs data processing and analysis for data-independent acquistion (DIA) proteomics data and was developed by Demichev, Ralser and Lilley Labs ([Ralser et al. 2020](https://www.nature.com/articles/s41592-019-0638-x)).

Native DIA-NN is designed to utilise up to all cores on a single node, and does not currently have multi-node capability. For experiments with high numbers of samples, processing DIA data can be time-consuming and require batch processing followed by batch correction. This workflow has been created to enable large sample cohorts to be analysed with DIA-NN as a single batch on HPC, thereby eliminating batch effects (Fig. 1) and vastly reducing compute walltime (Fig. 2). We have achieved speedups of 61X and 145X on large cohort Scanning SWATH and Zeno SWATH datasets, respectively. 

<figure>
    <img src=.figs/batch_effects.png width="75%" height="75%">
    <figcaption><b>Fig.1 a.</b>  Batch-processing of 1530 Scanning SWATH samples over 10 batches using DIA-NN GUI on PC.  <b>b.</b> Processing the same 1530 samples using this Scalable-DIA-NN workflow on HPC. </figcaption>
</figure>  


</br></br>

<figure>
    <img src=.figs/speedup.png width="75%" height="75%">
    <figcaption><b>Fig.2</b> Comparison of compute between PC GUI DIA-NN and Scalable-DIA-NN over two large-cohort datasets.</figcaption>
</figure>  


</br></br>


To tease apart the DIA-NN run command into discrete jobs, we followed the steps recommended by the primary developers of DIA-NN and [quantms](https://quantms.readthedocs.io/en/latest/), described in this [Github issue](https://github.com/bigbio/quantms/issues/164). Quantms is a scalable nextflow workflow of DIA-NN, but currently does not work on NCI Gadi or Pawsey Nimbus (suspect that it is due to MacOS vs Linux incompatibilities) and hence this workflow was re-created here.

Importantly, our workflow differs from quantms as it takes .wiff files as input,  where quantms requires mzML input. Converting .wiff files to the universal mzML format has two important downsides:

- Converting wiff to mzML requires 1-2 hours compute per sample and necessitates a double-up of raw data stored
- We have found susbstantial [deleterious impacts on the results](https://github.com/vdemichev/DiaNN/issues/777) when processing the same samples from wiff or mzML format with identical run parameters

To avoid the use of mzML, we use the Windows version of DIA-NN on Linux by executing with Wine (a PC emulator). We have installed Windows DIA-NN v. 1.8.1 with Wine 7 and packaged this into an archive [available here](https://www.dropbox.com/scl/fo/9ztilfixb8ozqsjdd0yz9/h?rlkey=7s8oncyn7lclzckkwq0ql3ywd&dl=0). We developed this workflow on [NCI Gadi HPC](https://nci.org.au/our-systems/hpc-systems), which has a Lustre scratch filesystem. We found we were unable to execute PC DIA-NN with Wine when the installation folder was on Lustre, so the workflow copies the archive to the solid-state local-to-the-node storage for each task.    

</br>

<details>
<summary><b>Portability</b></summary>

## Portability

This workflow uses `nci-parallel` utility to parallelise processing across the NCI Gadi cluster. As such, it curently works out of the box only on NCI Gadi.

Users are free to adapt it for use on other platforms, for example by replacing the `nci-parallel` parallelisation method with Open-MPI, job arrays, or simple for-loops. 

If adapting this workflow to another compute environment, please refer to the earlier notes regarding issues executing the Wine DIA-NN installation from Lustre.

A future release will see the workflow written in Nextflow. This imminent release will be portable. 


</details>

<details>
<summary><b>CPU efficiency</b></summary>

## CPU efficiency

This workflow has fairly poor CPU efficiency, in part to do with DIA-NN itself (which was not written to be parallelised in this way) and in part due to running a PC tool under Wine on a Linux platform. Tasks have approximately double walltime compared to when running Linux DIA-NN on mzML input. However, walltime, KSU and disk is saved from not requiring the wiff &rarr; mzML conversion step, as well as the [improvement in results](https://github.com/vdemichev/DiaNN/issues/777) when using wiff input. 

Updating to a Wine 8 container (currently using 7.0.0) may also help, and remains a plan for future testing. 

</details>

<details>
<summary><b>Parameters</b></summary>

## Parameters

Please refer to the [DIA-NN documentation - command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference) for parameters. **Note that the DIA-NN CLI defaults are not the same as the GUI and you should explicitly set parameters**. Also note that the GUI defaults have changed between DIA-NN versions 1.8.0 and v 1.8.1. 

Some parameters are hard-coded within this workflow and some are specified by the user within a setup script. Within the setup script is an `extra_flags` parameter that can be used to add any of DIA-NN's many flags to the workflow. Note that anything provided in `extra_flags` will be added to ALL steps in the workflow, and we have not tested every possible combination of flags. As such, it may be possible to encounter errors or warnings if a flag has been applied to a DIA-NN step for which it is not valid.

Parameters which have been hard-coded (may change when Nextflowed):

- `rt-profiling` (smart profiling yielded no benefit for a much slower run time) 
- `pg-level 2`
- `qvalue 0.01` 

At the time of writing, we have tested the following extra flags:

- `int-removal 0`
- `peak-center`
- `no-ifs-removal`
- `scanning-swath`

By adding `--int-removal 0`, `--peak-center` and `--no-ifs-removal`, this best matches the defaults from the GUI v 1.8.0 when:

-  quantification strategy is selected as `Any LC (high accuracy)`
-  `MBR`, `reannotate`, `fasta digest` and `deep learning` are checked
- `heuristic protein inference` and `no shared spectra` are unchecked  

The `scanning-swath` parameter should be applied if the data was generated as ScanningSWATH. When running the DIA-NN GUI, this is detected automatically - note that this is NOT the case when running this workflow. 

</details>

<details>
<summary><b>Input requirements</b></summary>

## Input requirements

### Data
In addition to the wiff and wiff.scan inputs, a fasta is required, and a spectral library can be either supplied or created with optional `Step 1`. A cohort-specific empirical library is generated using the spectral library and input samples.

### DIA-NN resources
PC DIA-NN executable installed with Wine is required, and must be run with Wine from the local-to-node storage (will not work from Lustre filesystem).We have installed DIA-NN v 1.8.1 with [Wine 7.0.0](https://hub.docker.com/r/uvarc/wine) and copied the 'Clearcore' and 'Sciex' dll files (required for DIA-NN to read wiff input) into the DIA-NN install directory as per developer's guidelines. We have packaged this up into an archive named `dot_wine.tar`. Many thanks to [NCI](nci.org.au) for assistance with this. This archive (1.8 GB) and its md5 checksum file is available on Dropbox, and download details are provided under the [user guide](#detailed-user-guide)


The `dot_wine.tar` DIA-NN installation requires Wine with Mono to run. We have successfully used the [uvarc container](https://hub.docker.com/r/uvarc/wine) and the [Proteowizard container](https://hub.docker.com/r/chambm/pwiz-skyline-i-agree-to-the-vendor-licenses). The Proteowizard container requires [per-user set-up](#pwiz_image_setup.md) to run on Gadi.

For a library-free analysis, in-silico library generation should be performed with the [Linux version of DIA-NN](https://docker.ecosyste.ms/packages/biocontainers%2Fdiann/versions/v1.8.1_cv1) rather than the Wine-installed PC version. This is simply because the Linux version is much faster (3 minutes vs 45 minutes for a mammalian proteome).


</details>

<details>
<summary><b>Overview of workflow steps</b></summary>


## Overview of workflow steps

**Environment setup:** Clone the repository and establish required input files

**0. Parameter setup:** user configures parameters and then runs the setup script to set up the working directory, scripts and required inputs files

**1. Optional in-silico library creation:** see [Library method options](#library-method-options)

**2. Parallel initial quantification of samples**, using the in-silico library, experimentally-generated spectral library, or both 

**3. Creation of cohort-specific empirical library**

**4. Parallel final quantification of samples**, using the cohort-specific empirical library 

**5.  Creation of gene matrix and statistics output files**

**6.  Optional filtering** step to remove genes with high missing values

</details>

<details>
<summary><b>Library method options</b></summary>

### Library method options

This workflow has three library options:

#### 1. Library-based

A cohort-specific, experimentally generated spectral library is available for the experiment. 

To perform a library-based analysis, library settings for the parameter configuration performed at step 0 will be:

``` 
insilico_lib_prefix=false
spectral_lib=<filepath of experimental spectral library>
```

Step 1 of the workflow is skipped. 

#### 2. Library-free

No cohort-specific, experimentally generated spectral library is available for the experiment, so an in-silicio spectral library created from a digest of the proteome fasta is required. 

To perform library-free analysis, library settings for the parameter configuration performed at step 0 will be:

```
insilico_lib_prefix=<desired library prefix name>
spectral_lib=false
```

Step 1 of the workflow is required.

#### 3. Belts-and-braces

To use *both* a proteome fasta and a cohort-specific experimentally generated spectral library to produce the insilico library, apply the following settings at step 0:

```
insilico_lib_prefix=<desired library prefix name>
spectral_lib=<ilepath of experimental spectral library>
```

Step 1 of the workflow is required. 

#### Library choice

Library-free analysis is [recommended by DIA-NN developers](https://github.com/vdemichev/DiaNN?tab=readme-ov-file#library-free-search) for most experiments.

 We compared library-free vs library-based for the 1530-sample cohort referenced in Figs 1 and 2: 

 **results tba**



</details>

<details>
<summary><b>Detailed user guide</b></summary>

## Detailed user guide

### Setup the repository 

Navigate to your working directory on NCI Gadi (or your own infrastructure, please note script adjustments will be required as previosuly noted):

```
cd /scratch/<project>
```

Clone the repository and change into it:
```
git clone git@github.com:Sydney-Informatics-Hub/Scalable-DIA-NN.git
cd Scalable-DIA-NN
```

### Obtain required input files

Ensure your proteome fasta and all wiff and wiff.scan files are copied to an accessible filesystem. These do not need to be within the cloned repository. 

If not already obtained, get the required DIA-NN resources to run this workflow:

```
# Optional directory for the resources
mkdir diann_resources
cd diann_resources

# dot_wine.tar
wget -O dot_wine.tar https://www.dropbox.com/scl/fi/4rq4mtdsu6sggw3oa57ji/dot_wine.tar?rlkey=i82v6c4o9aw3qomgtv9y2e4bv&dl=0
wget -O dot_wine.tar.md5 https://www.dropbox.com/scl/fi/rqcnjfxzr5se9l40q09nv/dot_wine.tar.md5?rlkey=l5pvhxwp7to5qz3gwijdkvfcd&
md5sum -c dot_wine.tar.md5

# Wine to run the PC version of DIA-NN:
module load singularity
singularity pull docker://uvarc/wine:7.0.0

# Linux DIA-NN, only required for optional step 1:
singularity pull docker://biocontainers/diann:v1.8.1_cv1
```

Once these required files are available in your environment, proceed to parameter setup. 

### 0. Parameter setup

Open `Scripts/0_setup_params.txt` with your preferred text editor. Edit the parameters to suit your experiment, then save. Details for each parameter are below.

- `wiff_dir` : full path on Gadi to the parent directory containing wiff/wiff.scan input data. Note that .wiff and .wiff.scan files are required. All files ending in .wiff in the indir will be operated on. If the parent wiff directory contains samples you wish to exclude, please use symlinks to establish a directory that contains only the samples you want to analyse.Wiff files can be in subdirectories inside the parent indir, and/or symlinked from other locations. A 'Raw_data' directory will be created in the base working directory with symlinks to all data files. This is necessary to circumvent exceeding the ARG_MAX limit for the non-parallel steps (command too long for large cohorts). 

- `cohort` : cohort name, to be used as prefix for output files. Eg 'muscle_libfree'. The number of samples will be auto-added to output file names. 

- `insilico_lib_prefix` : desired library prefix name, or 'false'. eg 'mouse_proteome'. See [Library method options](#library-method-options).

- `spectral_lib` : spectral library filepath or 'false'. See [Library method options](#library-method-options).

- `fasta` : proteome fasta for the target species. Multiple fasta (for example, a proteome plus a contaminants fasta) can be provided as a single string separated by a comma, eg `fasta=/path/to/fasta1.fasta,/path/to/fasta2.fasta)`

- `subsample` : enter `true` or `false`. If no prior information is known about the best settings for scan window and mass accuracy, 'true' is recommended. If true, N% of samples will be selected and initial quantification performed using 'auto' for mass accuracy, MS1 accuracy and scan window parameters. Recommended values for these parameters will then be averaged from the subsamples (using `Scripts/2_subsample_averages.pl`), and applied to the workflow. If false, user must specify either 'auto' or '<fixed_value>' for these parameters within the setup script. If true, any values entered for these parameters are ignored.

- `percent` : if performing subsampling, percent of samples to subsample. Samples will be selected from the name-sorted list of samples evenly spaced along the list. The intention is for the Nextflow version of this workflow to enable over-ride with a user-provided list of subsamples. 

- `scan_window` : enter 'auto' or an integer. If 'auto', user can choose whether to run the entire workflow with 'auto' (not recommended) or run only steps 2-3 with 'auto', followed by `Scripts/4_individual_final_analysis_setup_params.pl` to extract the 'Averaged recommended settings for this experiment' from the step 3 log file and apply it to the scripts for steps 4-5. This will likely give almost as good results as using the subsampling method.

- `mass_accuracy` :  enter 'auto' or a fixed value (floating point or integer). As above.

- `ms1_acc` :  enter 'auto' or a fixed value (floating point or integer). As above.

- `missing` : integer 0-100. Optionally, filter away genes from the final unique genes matrix with fewer than N% samples called. The full unfiltered output is retained, the filter `Scripts/6_filter_missing.pl` creates new files with kept and discarded genes.

- `extra_flags` : Add any extra flags here. These will be applied to all steps. It's too complex to derive which of all the many DIA-NN flags apply to which steps and in which recommended combinations. If you find that you have added a flag here and you receive an error at part of the workflow due to a conflicting flag or clash or a flag not being permitted at a certain command, sorry, please fix manually, document, and rerun :blush:. Please add flags in exact notation as you would on DIA-NN command line, and encase in double quotes, example: `extra_flags="--int-removal 0 --peak-center --no-ifs-removal --scanning-swath"`.

- `project` : Your NCI project code. This will be added to the PBS scripts for accounting.

- `lstorage` : Path to the storage locations required for the job. Must be in NCI-required syntax, ie ommitting leading slash, and no spaces, eg `"scratch/<project1>+scratch/<project2>+gdata<project3>"`. Note that your job will fail if read/write is required to a filesystem path not included. If you have symlinked any inputs, ensure the link source is included.

- `wine_tar` : path to your [dot_wine.tar archive](#dia-nn-resource). This archive will be copied to `jobfs` for every job and sub-task. 

- `wine_image` : path to the [Wine plus Mono singularity container](#wine-singularity-container). 

- `diann_image` : path to the DIA-NN v 1.8.1 singularity container `diann_v1.8.1_cv1.sif`. Only required if you are running step 1, otherwise, leave blank.


Once these configurations have been made, save the parameters file, then run:

```
bash Scripts/0_setup.sh
```

User-specified parameters will be updated to all scripts in the workflow. The only script edits users need to make are to PBS job resources (ie CPU, MEM, and waltime). This has not been automated, as there is some nuance to it, and will be obsolete once the workflow has been Nextflowed. 

### 1. In silico library generation (optional) 

Step 1 is required for a library free or 'belts and braces' analysis, but not for library-based - see [Library method options](#library-method-options).

If performing library-based analysis against a cohort-specific experimentally generated spectral library, skip to [step 2](#2-preliminary-quantification-parallel).


Begin by confirming the digest parameters you would like to apply by checking the DIA-NN [command-line reference](https://github.com/vdemichev/DiaNN?tab=readme-ov-file#command-line-reference). If you have a previous GUI DIA-NN library free run log which applied settings you want to use, you can extract these from the diann.exe command contained at the start of the log. 

Manually adjust the digest parameters in `Scripts/1_generate_insilico_lib.pbs` to reflect your desired settings. 

The script out of the box has defaults of:
```
        --min-fr-mz 200 \
        --max-fr-mz 1800 \
        --met-excision \
        --cut K*,R* \
        --missed-cleavages 1 \
        --min-pep-len 7 \
        --max-pep-len 30 \
        --min-pr-mz 400 \
        --max-pr-mz 900 \
        --min-pr-charge 1 \
        --max-pr-charge 4 \
        --unimod4
```


Once the digest settings have been tailored to your needs, submit step 1:
```
qsub Scripts/1_generate_insilico_lib.pbs
```

This will create an insilico spectral library and log file:
```
./1_insilico_library/<insilico_lib_prefix>.predicted.speclib
./1_insilico_library/<insilico_lib_prefix>.log.txt
```


### 2. Preliminary quantification (parallel)

This step performs preliminary quantification of all input samples in parallel, using either the spectral library generated at step 1 (library free or 'belts and braces'), or the experimentally generated spectral library (library-based). Note that for this and subsequent steps, you do not need to manually edit the library or other inputs - this is performed when the setup script is executed. Only step 1 digest parameters need manual adjustment, and the resource requests for the PBS jobs according to cohort size.  

#### With 'subsampling'

If `subsample` was set to 'true' in the setup script, 10% (or whatever percentage user defined) of samples have been selected and printed to a list: `Inputs/2_preliminary_analysis_subsample.list`, and input configurations for these samples printed to `Inputs/2_preliminary_analysis.inputs`. 

To run the step 2 subsampling, update resources in `Scripts/2_preliminary_analysis_run_parallel.pbs`, allowing 12 CPU, 48 GB RAM and 10 GB jobfs per sample. Gadi multi-node jobs **MUST REQUEST WHOLE NODES** so please round up to the nearest whole node. When using >= 1 node, request 190 GB RAM per node and 400 GB jobfs per node. 

Save the script, then submit:
```
Scripts/2_preliminary_analysis_run_parallel.pbs
```

Run times up to 40 minutes have been observed for large Scanning SWATH files. Zeno SWATH files up to 10 minutes each. Allowing generous walltimes is not recommended for jobs requesting large numbers of nodes, as this can waste KSU if a small number of samples requires a longer run time. Its best to let these few samples fail and be detected with the checker script. 

After the subsampling job has finished, run the checker script:

```
Scripts/2_preliminary_analysis_check.sh
```

Any failed tasks will be written to `Inputs/2_preliminary_analysis.inputs-failed`, with a message to update resources to match the number of failed samples in `Scripts/2_preliminary_analysis_run_parallel_failed.pbs` and then submit. 

After the failed tasks job has completed, run the checker script again, and if necessary, repeat the process until no more failed tasks are found. 

Once all subsample tasks have successfully completed, extract the average recommended settings for scan window, mass accuracy and MS1 accuracy:

```
perl Scripts/2_subsample_averages.pl
```

This will report the averages derived from the subsamples, and update them to all scripts in the workflow. The workflow is to be resumed from step 2, with all samples in cohort (including the subsamples). The above perl script also updates the inputs configuration file for step 2 to include all samples in cohort. Now continue to the next section. 

#### Run step 2 on all samples

If `subsample` was set to 'false' during setup: you have entered fixed values or 'auto' for scan window, mass acuracy and MS1 accuracy. In either case, or if you have just completed the 'with subsampling' section above, this step is the same. 

Update resources in `Scripts/2_preliminary_analysis_run_parallel.pbs`, allowing 12 CPU, 48 GB RAM and 10 GB jobfs per sample. Gadi multi-node jobs **MUST REQUEST WHOLE NODES** so please round up to the nearest whole node. When using >= 1 node, request 190 GB RAM per node and 400 GB jobfs per node. 

Save the script, then submit:
```
Scripts/2_preliminary_analysis_run_parallel.pbs
```

Run times up to around 40 minutes have been observed for large Scanning SWATH files. Allowing generous walltimes is not recommended for jobs requesting large numbers of nodes, as this can waste KSU if a small number of samples requires a longer run time. Its best to let these few samples fail and be detected with the checker script. 

After the step 2 job has finished, run the checker script:

```
Scripts/2_preliminary_analysis_check.sh
```

Any failed tasks will be written to `Inputs/2_preliminary_analysis.inputs-failed`, with a message to update resources to match the number of failed samples in `Scripts/2_preliminary_analysis_run_parallel_failed.pbs` and then submit. 

After the failed tasks job has completed, run the checker script again, and if necessary, repeat the process of resubmitting and checking until no more failed tasks are found. 

Once all step 2 tasks have successfully completed, move on to step 3. 

#### Random task errors under Wine

Random errors may be encountered that look like this:

```
Cannot transition thread 000000000000014c from ASYNC_SUSPEND_REQUESTED with DONE_BLOCKING
```

The parallel steps (where these are most often observed, due to sheer numbers) each have checker scripts that will detect these (and other) task failures for ease of resubmission. 

### 3. Assemble empirical library

This is a non-parallel job that reads all the quantification files generated at step 2, together with the input in-silico spectral library, and creates a cohort-specific empirical spectral library. The subsequent steps requantifies all samples with this library. 

Example resource usage:

- 146 scanning SWATH samples, 12 CPU 'normal' queue: 14 minutes, 19 GB RAM
- 1530 scanning SWATH samples, 48 CPU 'normal' queue: 5 hours 35 minutes, 120 GB RAM
- 1381 non-scanning SWATH samples, 48 CPU 'normal' queue: 8  minutes, 14 GB RAM

As cohort size increases for large scanning SWATH samples, additional CPU are not particularly helpful, but additional RAM and a lot of additional walltime are required. 

Update resources in `Scripts/3_assemble_empirical_lib.pbs` then submit:
```
qsub  Scripts/3_assemble_empirical_lib.pbs
```

Once the job has completed, perform the following simple manual checks before proceeding to step 4:

- Job exit status 0:
```
$ grep Exit PBS_logs/step3_MM_Complete_Liver_Proteomics_1530s.o 
   Exit Status:        0
```
- No errors in PBS error log:
```
$ wc -l PBS_logs/step3_MM_Complete_Liver_Proteomics_1530s.e 
0 PBS_logs/step3_MM_Complete_Liver_Proteomics_1530s.e

```
- Log file describes a spectral library and ends in 'Finished':
```
$ tail Logs/3_assemble_empirical_lib.log 
[334:22] Loading the generated library and saving it in the .speclib format
[334:22] Loading spectral library 3_empirical_library/MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical
[334:29] Spectral library loaded: 12759 protein isoforms, 8342 protein groups and 39315 precursors in 32612 elution groups.
[334:29] Protein names missing for some isoforms
[334:29] Gene names missing for some isoforms
[334:29] Library contains 0 proteins, and 0 genes
[334:29] Saving the library to 3_empirical_library/MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical.speclib
[334:29] Log saved to 3_empirical_library/MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical.log.txt
Finished
```
Note that the message "Library contains 0 proteins, and 0 genes" within the log output is expected and benign. This does not affect the results. Playing around with parameters during testing, we were able to get this message to disappear, however the downstream results produced fewer genes than the version of parameters which yielded this unsettling message. There are genes and proteins in the library. 

- Output directory contains these 5 files:
```
$ ls -lh 3_empirical_library/
total 29G
-rw-r--r-- 1 cew562 xh27 111M Oct 20 04:21 MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical
-rw-r--r-- 1 cew562 xh27 3.2K Oct 20 04:21 MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical.log.txt
-rw-r--r-- 1 cew562 xh27  29G Oct 20 04:20 MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical.report
-rw-r--r-- 1 cew562 xh27  12M Oct 20 18:28 MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical.speclib
-rw-r--r-- 1 cew562 xh27 234K Oct 20 04:20 MM_Complete_Liver_Proteomics_1530s_mouse_proteome.empirical.stats.tsv
```

### 4. Final quantification (parallel)

 If 'auto' scan window, mass accuracy and MS1 accuracy parameters were applied for steps 2 and 3, users can opt to run a script that will extract the average recommended parameters from the step 3 log and apply these to the remainder of the workflow. 

 Note that this step is NOT required if fixed parameters have been included at steps 2 and 3 (either from subsampling, or fixed from step 0). 

#### Optional step to extract recommended parameters from 'auto' runs

Run the following: 

```
perl Scripts/4_individual_final_analysis_setup_params.pl
```

This will update the recommended parameters to the scripts for steps 4 and 5, as well as update the step 4 inputs configuration file, changing 'auto' to the new recommended parameters. 

After running this script, run step 4 as usual. 

#### Run step 4 on all samples

Update resources in `Scripts/4_individual_final_analysis_run_parallel.pbs`, allowing 4 CPU, 16 GB RAM and 10 GB jobfs per sample. Gadi multi-node jobs **MUST REQUEST WHOLE NODES** so please round up to the nearest whole node. When using >= 1 node, request 190 GB RAM per node and 400 GB jobfs per node. 

Save the script, then submit:
```
qsub Scripts/4_individual_final_analysis_run_parallel.pbs
```

Run times up to around 1.5 hours have been observed for large Scanning SWATH files. Allowing generous walltimes is not recommended for jobs requesting large numbers of nodes, as this can waste KSU if a small number of samples require a longer run time. Its best to let these few samples fail and be detected with the checker script. 

After the step 4 job has finished, run the checker script:

```
bash Scripts/4_individual_final_analysis_check.sh
```

Any failed tasks will be written to `Inputs/4_individual_final_analysis.inputs-failed`, with a message to update resources to match the number of failed samples in `Scripts/4_individual_final_analysis_run_parallel_failed.pbs` and then submit. 

After the failed tasks job has completed, run the checker script again, and if necessary, repeat the process of resubmitting and checking until no more failed tasks are found. 

Once all step 4 tasks have successfully completed, move on to step 5.

### 5. Summarise analysis

This step reads the final quantification files and cohort-specific spectral library to create final matrices and stats report files. 

Example resource usage:

- 146 samples scanning SWATH, 24 CPU 'normal' queue: 12 minutes, 17 GB RAM
- 1530 samples scanning SWATH, 28 CPU 'normalbw' queue: 7 hrs 41 mins, 104 GB RAM 
- 1381 samples non-scanning SWATH, 24 CPU 'normal queue: 9 minutes, 15 GB RAM

As cohort size increases, additional CPU are not particularly helpful, but additional RAM and a lot of additional walltime are required. 

Update resources in `Scripts/5_summarise.pbs` and submit:

```
qsub Scripts/5_summarise.pbs
```

Once the job has completed, perform the following simple manual checks:

- Job exit status 0:
```
$ grep Exit PBS_logs/step5_MM_Complete_Liver_Proteomics_1530s.o
   Exit Status:        0
```
- No errors in PBS error log:
```   
$ wc -l PBS_logs/step5_MM_Complete_Liver_Proteomics_1530s.e 
0 PBS_logs/step5_MM_Complete_Liver_Proteomics_1530s.e
```

- Log file describes matrix files and ends in 'Finished':
```
$ tail Logs/5_summarise.log 
[458:38] Saving protein group levels matrix
[459:09] Protein group levels matrix (1% precursor FDR and protein group FDR) saved to 5_summarise/MM_Complete_Liver_Proteomics_1530s_diann_report.pg_matrix.tsv.
[459:09] Saving gene group levels matrix
[459:39] Gene groups levels matrix (1% precursor FDR and protein group FDR) saved to 5_summarise/MM_Complete_Liver_Proteomics_1530s_diann_report.gg_matrix.tsv.
[459:39] Saving unique genes levels matrix
[460:09] Unique genes levels matrix (1% precursor FDR and protein group FDR) saved to 5_summarise/MM_Complete_Liver_Proteomics_1530s_diann_report.unique_genes_matrix.tsv.
[460:09] Stats report saved to 5_summarise/MM_Complete_Liver_Proteomics_1530s_diann_report.stats.tsv
[460:09] Log saved to 5_summarise/MM_Complete_Liver_Proteomics_1530s_diann_report.log.txt
Finished

```
-  Output directory contains these 7 files:
```
$ ls -lh 5_summarise/
total 33G
-rw-r--r-- 1 cew562 xh27  36M Oct 21 02:07 MM_Complete_Liver_Proteomics_1530s_diann_report.gg_matrix.tsv
-rw-r--r-- 1 cew562 xh27 3.5K Oct 21 02:08 MM_Complete_Liver_Proteomics_1530s_diann_report.log.txt
-rw-r--r-- 1 cew562 xh27  37M Oct 21 02:07 MM_Complete_Liver_Proteomics_1530s_diann_report.pg_matrix.tsv
-rw-r--r-- 1 cew562 xh27 315M Oct 21 02:06 MM_Complete_Liver_Proteomics_1530s_diann_report.pr_matrix.tsv
-rw-r--r-- 1 cew562 xh27 234K Oct 21 02:08 MM_Complete_Liver_Proteomics_1530s_diann_report.stats.tsv
-rw-r--r-- 1 cew562 xh27  32G Oct 21 02:02 MM_Complete_Liver_Proteomics_1530s_diann_report.tsv
-rw-r--r-- 1 cew562 xh27  32M Oct 21 02:08 MM_Complete_Liver_Proteomics_1530s_diann_report.unique_genes_matrix.tsv

```
### 6. Optional filter for missing values

The setup script included a `missing` parameter. This is a percentage threshold of samples with abundance values below which to discard a gene. To filter the final unique genes matrix to include only genes with at least N% of samples with abundance values, run the following:

```
perl Scripts/6_filter_missing.pl
```

This will create 2 additional files in the `5_summarise` output directory:
- `\<cohort_name\>_\<number-of-samples\>s_diann_report.filter-\<N\>-percent.unique_genes_matrix.tsv`
- `\<cohort_name\>_\<number-of-samples\>s.filter-\<N\>-percent.discarded_genes.txt`

The filtered unique genes matrix has the same format as the standard DIA-ANN unique genes matrix. The discarded genes file is a 2-column TSV with gene name and % of samples with no value for that gene. 

</details>

