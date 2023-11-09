#!/bin/bash

# Run this before commencing the analysis to automate updates to scripts
# First, adjust parameters, then submit with 'bash Scripts/setup_scripts.sh'


#--------------------------------------------------------------------------------
#### PARAMS TO BE ADJUSTED BY USER ####

# Input wiff directory:
## NOTE: this will run DiaNN over ALL SAMPLES ending in .wiff in the indir
## Wiff files can be in subdirectories inside the parent indir, and/or symlinked
## To run on a subset of sample, please make a directory with this subset of wiff and wiff.scan files symlinked
## A 'Raw_data' directory will be created in the base working directory with symlinks to all data files
## This is necessary to circumvent exceeding the ARG_MAX limit for the non-parallel steps (command too long for large cohorts) 

wiff_dir=
 
#-----

# Cohort name (number of samples will be auto-added):

cohort=

#-----

# Spectral library:
# This is not sample/cohort specific - can be pre-made and re-used across multiple experiments
# If no spectral library, enter 'auto' and run Step 1 after runing this setup script. 

#### AUTO FUNCTIONALITY NOT YET DONE!####

spectral_lib=

#-----

# Empirical library outfile name (number of samples used in its creation will be added):
# This is cohort- specific: generated from the non-specific speclib and the sample outputs from step 2
# 2 files will be made with this prefix - an empirical/predicted speclib in TSV format the same in 'speclib' format 

empirical_lib_prefix=

#-----

# Fasta: 

fasta=

#-----

# Subsample method:
# If subsample is true, N% (default is 10) will be selected and processed with 'auto' settings
# for scan window, mass accuracy and MS1 accuracy for step 2, in parallel. 
# Then, an additional script 'subsample_averages.pl' is to be run by user, which will extract the 
# "Average recommended settings for this experiement" from the logs of these samples, 
# take the average across the sub-sampled samples, and apply them to all scripts in the 
# workflow. Then, the whole workflow (starting from step 2) is to be run on all samples, with these 
# derived averages as fixed values. 
# User can change the % of samples to subsample if desired, or leave as the default of 10.
# If subsample is true, there is no need to change the values for scan window, mass accuracy or 
# ms1 accuracy in this setup script (they will be ignored).
# If subsample is false, user must set these 3 parameters to either auto or some value. 

# 'true' or 'false':
subsample= 

# Number 1-99:
percent=  

#### MANUAL SUBSAMPLE LIST OVER-RIDE NOT YET DONE!####
   
#-----

# Scan window ('auto' or integer):

scan_window= 
   
#-----

# Mass accuracy ('auto' or numeric) 

mass_acc=
   
#-----

# MS1 accuracy ('auto' or numeric) 

ms1_acc=
   
#-----

# Filter for missingness: minimum percent of samples required with gene detected to keep a gene
# Note: the full unfiltered output is retained, the filter creates new files with kept and discarded genes 

missing=

#-----

# Extra flags: 
# Add any extra flags here. these will be applied to all steps. Its too complex to derive which of all the many
# DiaNN flags apply to which steps, if you find that you have added a flag here and you receive an error at part
# of the workflow due to a conflicting flag or clash or a flag not being permitted at a certain command, sorry 
# please fix manually, document, rerun. :-) 
# Please add flags in exact notation as you would on DiaNN command line, and encase in double quotes. 
# Please only add '--scanning-swath' if your data was generated in this way
# Note that scaning-swath is not auto-detected on the CLI like it is by the GUI  

# Example value: "--int-removal 0 --peak-center --no-ifs-removal --scanning-swath"

extra_flags=

#-----

# Accounting:

# 4 digit NCI project code: 
project=

# storage paths in mandated NCI format (ie no leading forward slash, + between paths, no whitespace, gdata not 'g/data/')
# Example: "scratch/ab12+gdata/cd34"
lstorage=

#-----

# dot wine tar folder with DiANN.exe installed

wine_tar=

#-----

# wine singularity container 

wine_image=

#-----

#### END OPTION SETTING ####
########################################
#--------------------------------------------------------------------------------
# Make required workflow directories:
mkdir -p Logs PBS_logs Inputs Raw_data

for wiff in `find -L ${wiff_dir} -name "*.wiff" -exec realpath -s {} \;`
do
	ln -s $wiff Raw_data/
	ln -s ${wiff}.scan Raw_data/
done

#--------------------------------------------------------------------------------
# PBS stuff - accounting, storage and logs

# Update project and storage: 
sed -i "s|^#PBS -P.*|#PBS -P ${project}|g" ./Scripts/*pbs
sed -i "s|^#PBS -l[ ]*storage.*|#PBS -l storage=${lstorage}|g" ./Scripts/*pbs


# Update PBS log output file names according to number of samples:  
n=$(ls -1 Raw_data/*wiff | wc -l)

for ((i = 2; i <=5; i++)) # step 2 through to step 5 in the workflow 
do
	sed -i "s|^#PBS -o.*|#PBS -o ./PBS_logs/step${i}_${cohort}_${n}s.o|g" Scripts/${i}*pbs
	sed -i "s|^#PBS -e.*|#PBS -e ./PBS_logs/step${i}_${cohort}_${n}s.e|g" Scripts/${i}*pbs
done

#--------------------------------------------------------------------------------
# Setup 'failed' rerun scripts for parallel steps 

# Special log file names for run-failed PBS scripts:
scripts_to_update="Scripts/2_preliminary_analysis_run_parallel_failed.pbs"
sed -i "s|^#PBS -o.*|#PBS -o ./PBS_logs/step2_${cohort}_rerun_failed.o|g" $scripts_to_update
sed -i "s|^#PBS -e.*|#PBS -e ./PBS_logs/step2_${cohort}_rerun_failed.e|g" $scripts_to_update

scripts_to_update="Scripts/4_individual_final_analysis_run_parallel_failed.pbs"
sed -i "s|^#PBS -o.*|#PBS -o ./PBS_logs/step4_${cohort}_rerun_failed.o|g" $scripts_to_update
sed -i "s|^#PBS -e.*|#PBS -e ./PBS_logs/step4_${cohort}_rerun_failed.e|g" $scripts_to_update

scripts_to_update="Scripts/2_preliminary_analysis_check.sh"
step=2
sed -i "s|^log_prefix=.*|log_prefix=step${step}_${cohort}|g" $scripts_to_update
sed -i "s|^subsample=.*|subsample=${subsample}|g" $scripts_to_update

scripts_to_update="Scripts/4_individual_final_analysis_check.sh"
step=4
sed -i "s|^log_prefix=.*|log_prefix=step${step}_${cohort}|g" $scripts_to_update

#--------------------------------------------------------------------------------
# Add extra flags to steps 2-5: 

scripts_to_update="Scripts/2_preliminary_analysis.sh Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis.sh Scripts/5_summarise.pbs"
sed -i "s|^extra_flags=.*|extra_flags=\"${extra_flags}\"|g" $scripts_to_update


#--------------------------------------------------------------------------------
# Are we performing step 1?
# 3 options: 
# 1- do not use a spec lib at all, in which case all of the 2-5 scripts will need to be adjusted to allow for this
# 2 - use a pre-made speclib (current setup)
# 3 - make a speclib (step 1 - script is ready, buit its not incorporated into this setup script 

#### TBA!!! ####


#--------------------------------------------------------------------------------
# Setup window, mass acc and MS1 acc parameters based on user input:

if [[ $subsample == 'true' ]]
then 
	printf "Selecting ${percent}%% of samples from ${wiff_dir} for subsampling\n"
	
	# Run the subsample selector:
	list=Inputs/2_preliminary_analysis_subsample.list
	subsampled=$(perl Scripts/2_select_subsamples.pl $percent $n $list)
	printf "${subsampled} samples from total cohort of $n written to ${list}\n\n";
	
	# Make the inputs file for subsamples:
	bash Scripts/2_preliminary_analysis_make_input.sh 1 > /dev/null
	grep -f ${list} Inputs/2_preliminary_analysis.inputs > temp
	mv temp Inputs/2_preliminary_analysis.inputs

	# Add subsample info to PBS logs
	sed -i "s|^#PBS -o.*|#PBS -o ./PBS_logs/step2_${cohort}_${n}s_${percent}pcSubsample.o|g" Scripts/2_preliminary_analysis_run_parallel.pbs
        sed -i "s|^#PBS -e.*|#PBS -e ./PBS_logs/step2_${cohort}_${n}s_${percent}pcSubsample.e|g" Scripts/2_preliminary_analysis_run_parallel.pbs
	
	# Provide cohort, n and percent to subsample averages script, so that it may update the step 2 PBS log names: 
	sed -i "s|^my \$cohort[ ]=.*|my \$cohort = '${cohort}';|g" Scripts/2_subsample_averages.pl
	sed -i "s|^my \$n[ ]=.*|my \$n = ${n};|g" Scripts/2_subsample_averages.pl
	sed -i "s|^my \$percent[ ]=.*|my \$percent = ${percent};|g" Scripts/2_subsample_averages.pl
		
	scan_window=auto 
	mass_acc=auto
	ms1_acc=auto	
fi


## This part is just for print out to terminal, to show the params as they will be applied
### Scan windows
if [[ $scan_window  =~ ^[0-9]+$ ]]
then  
	windows="--window ${scan_window}"
	printf "Applying fixed scan window parameter:\n\t${windows}\n\n"
elif [[ $scan_window  =~ ^auto$ ]]
then
	windows="--individual-windows"
	printf "Applying automatic scan window parameter:\n\t${windows}\n\n"
else
	printf "Sorry, ${scan_window} not an accepted value for scan_window - please specify an integer or 'auto'\n\n"
	exit
fi

### Mass accuracy (MS2 acc)  
if [[ $mass_acc  =~ ^[0-9.]+$ ]]
then  
	printf "Applying fixed mass accuracy parameter:\n\t--mass-acc ${mass_acc}\n\n"
elif [[ $mass_acc  =~ ^auto$ ]]
then
	printf "Applying automatic mass accuracy parameters:\n\t--individual-mass-acc --quick-mass-acc\n\n"
else
	printf "Sorry, ${mass_acc} not an accepted value for mass_acc - please specify a number or 'auto'\n\n"
	exit
fi

### MS1 mass accuracy 
if [[ $ms1_acc  =~ ^[0-9.]+$ ]]
then  
	printf "Applying fixed MS1 mass accuracy parameter:\n\t--mass-acc-ms1 ${ms1_acc}\n\n"
elif [[ $ms1_acc  =~ ^auto$ ]]
then
	printf "Not specifying fixed MS1 mass accuracy\n\n"
	ms1_acc=0
else
	printf "Sorry, ${ms1_acc} not an accepted value for ms1_acc - please specify a number or 'auto'\n\n"
	exit
fi


## This part actually updates the scripts with the above info 
scripts_to_update="Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis_make_input.sh"
sed -i "s|^scan_window=.*|scan_window=${scan_window}|g" $scripts_to_update
sed -i "s|^mass_acc=.*|mass_acc=${mass_acc}|g" $scripts_to_update
sed -i "s|^ms1_acc=.*|ms1_acc=${ms1_acc}|g" $scripts_to_update


#--------------------------------------------------------------------------------
# Update fasta (steps 4 and 5):
scripts_to_update="Scripts/4_individual_final_analysis_make_input.sh Scripts/5_summarise.pbs"
sed -i "s|^fasta=.*|fasta=${fasta}|g" $scripts_to_update


#--------------------------------------------------------------------------------
# Update predicted_lib (steps 2 and 3): 

# Emprical lib vs spectral lib variables:

# LIB at step 2 is speclib in (gas phase) ie NOT cohort specific 
# It can either be generated from the "step 1" script (not yet added here) or used from elsewhere 
# eg previosuly made one from Mass Spec PC
# In the future, make this intelligent re if spectral lib supplied as input, do not run step 1 and use the 
# specified speclib
# If no spec lib provided as input, run step 1 and feed that lib forward to step 2
# LIB at step 3 is the same library as at step 2
# the 'outlib' parameter will hold the new cohort-specific lib that uses the inbput speclib, the input fasta, 
# and the input samples, to mae a new empirical/predicted lib
# LIB at step 4 is the speclib MADE BY STEP 3 ie IS cohort specific

# Input spectral lib, ie not cohort specific, is used as input for steps 2 and 3:
scripts_to_update="Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs"
sed -i "s|^spectral_lib=.*|spectral_lib=${spectral_lib}|g" $scripts_to_update

# Empirical lib (ie cohort specific) is used as output for step 3 and input for steps 4 and 5: 
# Update empirical library prefix (steps 3, 4, and 5):
scripts_to_update="Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis_make_input.sh Scripts/5_summarise.pbs"
empirical_lib=${cohort}_${n}s_${empirical_lib_prefix}.empirical
sed -i "s|^empirical_lib=.*|empirical_lib=${empirical_lib}|g" $scripts_to_update


#--------------------------------------------------------------------------------
# Update final outfile name

final_out=${cohort}_${n}s_diann_report.tsv
scripts_to_update="Scripts/5_summarise.pbs"
sed -i "s|^final_out=.*|final_out=${final_out}|g" $scripts_to_update

#--------------------------------------------------------------------------------
# Update final filter script:

scripts_to_update="Scripts/6_filter_missing.pl"
sed -i "s|^my \$cohort[ ]=.*|my \$cohort = '${cohort}';|g" $scripts_to_update
sed -i "s|^my \$n[ ]=.*|my \$n = ${n};|g" $scripts_to_update
sed -i "s|^my \$missing[ ]=.*|my \$missing = ${missing};|g" $scripts_to_update


#---------------------------------------
# Get wine running stuff

# Update dot_wine tar location, wine singularity image file, and input dir with wiff files, for all steps:
scripts_to_update="Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis_make_input.sh Scripts/5_summarise.pbs"
sed -i "s|^wine_tar=.*|wine_tar=${wine_tar}|g" $scripts_to_update
sed -i "s|^wine_image=.*|wine_image=${wine_image}|g" $scripts_to_update


#---------------------------------------
# Run the make input for step 2 and step 4
# If user has set windows and mas accs to auto, and wants to use the step 3 recs, 
# the inputs will just be over-ridden by script 4_individual_final_analysis_setup_params.pl later
# If subsampling is true, dont run these make inputs now, as they will be run after the 
# step 2 has been run on subsamples, with Scripts/2_subsample_averages.pl



if [[ $subsample != 'true' ]]
then 
	bash Scripts/2_preliminary_analysis_make_input.sh
	bash Scripts/4_individual_final_analysis_make_input.sh
else	
	printf "\n* Please update resources in Scripts/2_preliminary_analysis_run_parallel.pbs\n  for ${subsampled} samples, then submit.\n"
	printf "* After this job has successfully completed, please run Scripts/2_subsample_averages.pl\n"
	printf "* Then continue with the workflow, starting with Scripts/2_preliminary_analysis_run_parallel.pbs\n\n"
fi
#---------------------------------------

# Need to add the flexi for spectral lib - if not user supplied, created by step 1

# Save this somewhere -  for wiff in `find -L ${wiff_dir} -name "*.wiff" -exec realpath -s {} \;`































































#

