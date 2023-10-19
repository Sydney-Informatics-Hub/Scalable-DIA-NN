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

The parallel steps (where these are most often observed, due to sheer numbers) each have checker scripts that will deect these (and other) task failures for resubmission. 

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

Details TBA. 

### 2. Preliminary analysis (parallel quantification)

This step performs preliminary quantificaiton of all input samples in parallel, using the provided in-silico spectral library. 