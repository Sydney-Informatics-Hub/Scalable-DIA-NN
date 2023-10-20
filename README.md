# Scalable DIA-NN 

## Introduction

This workflow implements the CLI installation of [DIA-NN](https://github.com/vdemichev/DiaNN) in a highly scalable fashion. DIA-NN is a tool that performs data processing and analysis for data-independent acquistion (DIA) proteomics data and was developed by Demichev, Ralser and Lilley Labs ([Ralser et al. 2020](https://www.nature.com/articles/s41592-019-0638-x)).

The Windows version of the DIA-NN tool is used, in order to negate the need to convert wiff files to mzML, which proved to have [deleterious impacts on the results](https://github.com/vdemichev/DiaNN/issues/777
). Wine PC emulator is used to run Windows DIA-NN on [NCI Gadi HPC](https://nci.org.au/our-systems/hpc-systems), a Linux platform. We have utilised the [Proteowizard container](https://hub.docker.com/r/chambm/pwiz-skyline-i-agree-to-the-vendor-licenses) for this since it conveniently contains Wine and Mono. 

Native DIA-NN processes the input samples in series. This workflow has been created to run these steps in parallel, to massively speed up the analysis of large cohorts and avoid the need for processing in batches and downstream batch correction. 

To tease apart the DIA-NN run command into discrete jobs, we followed the steps recommended by the primary developers of DIA-NN and [quantms](https://quantms.readthedocs.io/en/latest/), described in this [Github issue #164](https://github.com/bigbio/quantms/issues/164). Quantms is intended to be a scalable nextflow workflow of DIA-NN, but currently does not work on NCI Gadi or Pawsey Nimbus (suspect that it is due to MacOS vs Linux incompatibilities) and hence this workflow was re-created here. Further, our workflow takes wiff input where quantms requires the extra 1-2 hour step of converting wiff to mzML, plus the concomitant negative effect on output.

### Portability

As at 2023-10-19, this workflow uses `nci-parallel` utility to parallelise processing across the NCI Gadi cluster. As such, it curently works only on NCI Gadi.

Users are free to adapt it for use on other platforms, for example by replacing the `nci-parallel` parallelisation method with Open-MPI or job arrays. 

A future release will see the workflow written in Nextflow. This imminent release will be portable. 

### Parameters

Please refer to the [DIA-NN documentation - command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference) for parameters. **Note that the DIA-NN CLI defaults are not the same as the GUI and you should explicitly set parameters**. Also note that the GUI defaults have changed between DIA-NN versions 1.8.0 and v 1.8.1. 

Some parameters are hard-coded within this workflow and some are specified by the user within a setup script. Within the setup script is an `extra_flags` parameter that can be used to add any of DIA-NN's many flags to the workflow. Note that anything provided in `extra_flags` will be added to ALL steps in the workflow, and we have not tested every possible combination of flags. As such, it may be possible to encounter errors or warnings if a flag has been applied to a DIA-NN step for which it is not valid.

Parameters which have been hard-coded (may change when Nextflowed):

- `rt-profiling` (smart profiling yileded no benefit for a much slower run time) 
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

The `scanning-swath` parameter should be applied if the data was generated as ScanningSWATH. 

### Input requirements

In addition to the wiff and wiff.scan inputs, a fasta is required, and a spectral library can be either supplied or created with optional `Step 1`. A cohort-specific empirical library is generated using the spectral library and input samples.

### Overview of workflow steps

0. Set up: user configures parameters and then runs this script to set up the working directory, scripts and required inputs files
1. Optional spectral library: since this is not cohort specific and based only on a fasta and specified digest parameters, user can supply previosuly generated spectral library, or create one here. 
2. Parallel initial quantification of samples, using the input spectral library 
3. Creation of cohort-specific empirical library
4. Parallel final quantification of samples, using the empirical library 
5. Creation of matrix and stats output files
6. Optional filtering step to remvoe genes with high missig values

### Random task errors under Wine

Random errors may be encountered that look like this:

```
Cannot transition thread 000000000000014c from ASYNC_SUSPEND_REQUESTED with DONE_BLOCKING
```

The parallel steps (where these are most often observed, due to sheer numbers) each have checker scripts that will detect these (and other) task failures for ease of resubmission. 

### Deprecated batching workflow

The initial release of this workflow included a method to scale by batching, on Ronin/AWS and Gadi. This method is not recommended as it has inherent batch effects that are difficult to resolve. Batch correction steps were not included in the workflow. The instructions have been retained in [Deprecated_RoninAWS](). 


## User guide


### Required input files

- A proteome fasta file
- A parent directory containing all of the wiff and wiff.scan files to be analysed
    - Data can be in sub-directories within the parent directory
    - Data can be symlinked 
- A spectral library file
    - If not available, can be generated at step 1
    - This file is not cohort-specific, so it can be re-used across multiple experiments  
- Tar archive containing the PC version of DIA-NN (included with this repo)
- Singularity container with Wine and Mono 

### 0. Setup

Navigate to your working directory on Gadi:

```
cd /scratch/<project>
```

Clone the repository and change into it:
```
git clone git@github.com:Sydney-Informatics-Hub/Scalable-DiaNN.git
cd Scalable-DiaNN
```

Open `Scripts/0_setup.sh` with your preferred text editor. Edit the following configuration options:

- `wif_dir` : full path on Gadi to the parent directory containing wiff/wiff.scan input data.
- `cohort` : cohort name, to be used as prefix for output files.
- `spectral_lib` : full filepath of the spectral library. This is not sample/cohort specific, so it can be pre-made and re-used across multiple experiments. If no spectral library, enter 'auto' and ensure to run Step 1: `1_generate_insilico_lib.pbs`. 
- `empirical_lib` : Empirical library output file name prefix. The number of samples used in its creation will be automatically apended to the prefix. This is cohort-specific: generated from the non-specific `spectral_lib` and the sample quantification outputs from step 2.
- `fasta` : proteome fasta for the target species. Must be the same as used to make the `spectral_lib`. 
- `subsample` : enter `true` or `false`. If no prior information is known about the best settings for scan window and mass accuracy, 'true' is recommended. If true, N% of samples will be selected and initial quantification performed using 'auto' for mass accuracy, MS1 accuracy and scan window parameters. Recommended values for these parameters will then be averaged from the subsamples (using `Scripts/2_subsample_averages.pl`), and applied to the workflow. If false, user must specify either 'auto' or '<fixed_value>' for these parameters within the setup script. If true, any values entered for these parameters are ignored. 
- `percent` : if performing subsampling, percent of samples to subsample. Samples will be selected from the name-sorted list of samples evenly spaced along the list. The intention is for the Nextflow version of this workflow to enable over-ride with a user-provided list of subsamples. 
- `scan_window` : enter 'auto' or an integer. If 'auto', user can choose whether to run the entire workflow with 'auto' (not recommended) or run only steps 2-3 with 'auto', followed by `Scripts/4_individual_final_analysis_setup_params.pl` to extract the 'Averaged recommended settings for this experiment' from the step 3 log file and apply it to the scripts for steps 4-5. This will likely give almost as good results as using the subsampling method. 
- `mass_accuracy` :  enter 'auto' or a fixed value (floating point or integer). As above.
- `ms1_acc` :  enter 'auto' or a fixed value (floating point or integer). As above.
- `missing` : integer 0-100. Optioanlly, filter away genes from the final unique genes matrix with fewer than N% samples called. The full unfiltered output is retained, the filter `Scripts/6_filter_missing.pl` creates new files with kept and discarded genes.
- `extra_flags` : Add any extra flags here. These will be applied to all steps. It's too complex to derive which of all the many DIA-NN flags apply to which steps and in which recommended combinations. If you find that you have added a flag here and you receive an error at part of the workflow due to a conflicting flag or clash or a flag not being permitted at a certain command, sorry, please fix manually, document, and rerun :blush:
- `project` : Your NCI project code. This will be added to the PBS scripts for accounting.
- `lstorage` : Path to the storage locations required for the job. Must be in NCI-required syntax, ie ommitting leading slash, and no spaces, eg `"scratch/<project1>+scratch/<project2>+gdata<project3>"`. Note that your job will fail if read/write is required to a path not included. If you have symlinked any inputs, ensure the link source is included.
- `wine_tar` : path to the Wine tar archive containing the installation of the PC version of DIA-NN, and 'Clearcore' and 'Sciex' dll files. This archive will be copied to `jobfs` for every job and sub-task. 
- `wine_image` : path to the Proteowizard singularity container (see setup details above). This container contains Wine and Mono, and is used to run the PC DIA-NN in the above tar archive. 

Once these configurations have been made, save the script and submit:

```
bash Scripts/0_setup.sh
```

User-specified parameters will be updated to the workflow. The only script edits users need to make are to PBS job resources. This has not been automated, as there is some nuance to it, and will be obsolete once the workflow has been Nextflowed. 

### 1. In silico library generation (optional) 

If you have a spectral library previosuly made frm your proteome fasta, that can be used. If not, run this step. 

Functionality TBA. 

### 2. Preliminary quantification (parallel)

This step performs preliminary quantification of all input samples in parallel, using the provided in-silico spectral library. 

#### 2. With 'subsampling'

If `subsample` was set to 'true' in the setup script, 10% (or whatever percentage user defined) of samples have been selected and printed to a list: `Inputs/2_preliminary_analysis_subsample.list`, and input configurations for these samples printed to `Inputs/2_preliminary_analysis.inputs`. 

To run the step 2 subsampling, update resources in `Scripts/2_preliminary_analysis_run_parallel.pbs`, allowing 12 CPU, 48 GB RAM and 10 GB jobfs per sample. Gadi multi-node jobs **MUST REQUEST WHOLE NODES** so please round up to the nearest whole node. When using >= 1 node, request 190 GB RAM per node and 400 GB jobfs per node. 

Save the script, then submit:
```
Scripts/2_preliminary_analysis_run_parallel.pbs
```

Run times up to around 40 minutes have been observed for large Scanning SWATH files. Allowing generous walltimes is not recommended for jobs requesting large numbers of nodes, as this can waste KSU if a small number of samples requires a longer run time. Its best to let these few samples fail and be detected with the checker script. 

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

#### 2. Run step 2 on all samples

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

### 3. Assemble empirical library

This is a non-parallel job that reads all the quantification files generated at step 2, together with the input in-silico spectral library, and creates a cohort-specific empirical spectral library. The subsequent steps requantifies all samples with this library. 

Example resource usage:

- 146 samples, 12 CPU, 'normal' queue: 19 GB RAM, 14 minutes walltime
- 1530 samples, 48 CPU, 'normal' queue: 120 GB RAM, 5 hours 35 minutes walltime

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

 Note that this step is NOT required if fixed parameters have been included at steps 2 and 3 (eitehr from subsampling, or fixed from step 0). 

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

Run times up to around 1.5 hours have been observed for large Scanning SWATH files. Allowing generous walltimes is not recommended for jobs requesting large numbers of nodes, as this can waste KSU if a small number of samples requires a longer run time. Its best to let these few samples fail and be detected with the checker script. 

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

- 146 samples, 24 CPU 'normal' queue: 12 minutes, 17 GB RAM
- 1530 samples, 28 CPU 'normalbw' queue: TBA

Update resources in `Scripts/5_summarise.pbs` and submit:

```
qsub Scripts/5_summarise.pbs
```

Once the job has completed, perform the following simple manual checks:

- Job exit status 0:
```
[cew562@gadi-login-01 Run3_subsampling_average_fixed]$ grep Exit PBS_logs/step5_run3_wiff_146s.o
   Exit Status:        0
```
- No errors in PBS error log:
```   
[cew562@gadi-login-01 Run3_subsampling_average_fixed]$ wc -l PBS_logs/step5_run3_wiff_146s.e 
0 PBS_logs/step5_run3_wiff_146s.e
```

- Log file describes matrix files and ends in 'Finished':
```
[cew562@gadi-login-01 Run3_subsampling_average_fixed]$ tail Logs/5_summarise.log 
[11:19] Saving protein group levels matrix
[11:20] Protein group levels matrix (1% precursor FDR and protein group FDR) saved to ./5_summarise/run3_wiff_146s_diann_report.pg_matrix.tsv.
[11:20] Saving gene group levels matrix
[11:20] Gene groups levels matrix (1% precursor FDR and protein group FDR) saved to ./5_summarise/run3_wiff_146s_diann_report.gg_matrix.tsv.
[11:20] Saving unique genes levels matrix
[11:21] Unique genes levels matrix (1% precursor FDR and protein group FDR) saved to ./5_summarise/run3_wiff_146s_diann_report.unique_genes_matrix.tsv.
[11:21] Stats report saved to ./5_summarise/run3_wiff_146s_diann_report.stats.tsv
[11:21] Log saved to ./5_summarise/run3_wiff_146s_diann_report.log.txt
Finished
```
-  Output directory contains these 7 files:
```
$ ls -lh 5_summarise/
total 3.4G
-rw-r--r-- 1 cew562 er01 3.5M Oct 13 22:31 run3_wiff_146s_diann_report.gg_matrix.tsv
-rw-r--r-- 1 cew562 er01  15K Oct 13 22:31 run3_wiff_146s_diann_report.log.txt
-rw-r--r-- 1 cew562 er01 3.8M Oct 13 22:31 run3_wiff_146s_diann_report.pg_matrix.tsv
-rw-r--r-- 1 cew562 er01  37M Oct 13 22:31 run3_wiff_146s_diann_report.pr_matrix.tsv
-rw-r--r-- 1 cew562 er01  28K Oct 13 22:31 run3_wiff_146s_diann_report.stats.tsv
-rw-r--r-- 1 cew562 er01 3.4G Oct 13 22:31 run3_wiff_146s_diann_report.tsv
-rw-r--r-- 1 cew562 er01 3.1M Oct 13 22:31 run3_wiff_146s_diann_report.unique_genes_matrix.tsv
```
### 6. Optional filter for missing values

The setup script included a `missing` parameter. This is a percentage threshold of samples with abundance values below which to discard a gene. To filter the final unique genes matrix to include only genes with at least N% of samples with abundance values, run the following:

```
perl Scripts/6_filter_missing.pl
```

This will create 2 additional files in the `5_summarise` output directory:
- <cohort_name>_<number-of-samples>s_diann_report.filter-30-percent.unique_genes_matrix.tsv
- <cohort_name>_<number-of-samples>s.filter-<N>-percent.discarded_genes.txt

The filtered unique genes matrix has the same format as the standard DIA-ANN unique genes matrix. The discarded genes file is a 2-column TSV with gene name and % of samples with no value for that gene. 

## A note on efficiency

This workflow has fairly poor CPU efficiency, in part to do with running a PC tool under Wine on a Linux platform. Tasks have approximately double walltime compared to when running Linux DIA-NN on mzML input. However, walltime, KSU and disk is saved from not requireng the wiff --> mzML conversion step, as well as the improvement in results when using wiff input. 

Additional benchmarking will be performed to determine minimum resource requirements per job without further increasing walltime. 