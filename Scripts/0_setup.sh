#!/bin/bash

# Run this before commencing the analysis to automate updates to scripts
# First, adjust parameters, then submit with 'bash Scripts/0_setup.sh'


#--------------------------------------------------------------------------------
#### PARAMS TO BE ADJUSTED BY USER ####

# Input wiff directory:
## NOTE: this will run DIA-NN over ALL SAMPLES ending in .wiff in the indir
## Wiff files can be in subdirectories inside the parent indir, and/or symlinked
## To run on a subset of sample, please make a directory with this subset of wiff and wiff.scan files symlinked
## A 'Raw_data' directory will be created in the base working directory with symlinks to all data files
## This is necessary to circumvent exceeding the ARG_MAX limit for the non-parallel steps (command too long for large cohorts) 

wiff_dir=
 
#-----

# Cohort name (number of samples will be auto-added):

cohort=

#-----

# Library method: 

# There are three possible options:

# - 1) use an experimental spectral library, no insilico fasta digest required
#	- this is the "library based" method described in DIA-NN README
#	- to use this method, the parameter settings should be:
#		insilico_lib_prefix=false
#		spectral_lib=<spectral library filepath>
#	- user does not run step 1 script
 
# - 2) perform an in-silico digest of a fasta file, no experimental spectral library
#	- this is the "library free" method described in DIA-NN README
#	- to use this method, the parameter settings should be:
#		insilico_lib_prefix=<desired library prefix name>
#		spectral_lib=false
#	- user runs step 1 script
#	
# - 3) perform an in-silico digest of a fasta WITH an experimental spectral library
# 	- this has been described as a "belts and braces" approach, and is not explicitly described in the DIA-NN README
#	but is a valid method when running on the GUI (user chooses fasta digest params AND laods a spectral library file) 
# 	- to use this method, the parameter settings should be:
#		insilico_lib_prefix=<desired library prefix name>
#		spectral_lib=<spectral library filepath>
#	- user runs step 1 script
#
# If an insilico library is created from a fasta only, this file is not cohort specific and can be re-used across
# multiple experiments of the same organism. 
# If the insilico library created from a fasta AND an experimentally derived spectral library, the resultatn library
# IS cohort specific and cannot be used in other experiments. 

insilico_lib_prefix=
spectral_lib=


#-----

# Fasta: 
# If multiple fasta files to be used, please add as a comma-delimited list, 
# eg 'fasta=fast1.fasta,fast2.fasta' 

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

subsample=true
percent=10 

#### MANUAL SUBSAMLE LIST OVER-RIDE NOT YET DONE!####
   
#-----

# Scan window ('auto' or integer):

scan_window=auto 
   
#-----

# Mass accuracy ('auto' or numeric) 

mass_acc=auto 
   
#-----

# MS1 accuracy ('auto' or numeric). 20 is fairly typical.  

ms1_acc=auto 
   
#-----

# Filter for missingness: minimum percent of samples required with gene detected to keep a gene
# Note: the full unfiltered output is retained, the filter creates new files with kept and discarded genes 

missing=30

#-----

# Extra flags: 
# Add any extra flags here. these will be applied to all steps. Its too complex to derive which of all the many
# DiaNN flags apply to which steps, if you find that you have added a flag here and you receive an error at part
# of the workflow due to a conflicting flag or clash or a flag not being permitted at a certain command, sorry 
# please fix manually, document, rerun. :-) 
# Please add flags in exact notation as you would on DiaNN command line, and encase in double quotes. 

# Added scanning swath here - was hardcoded into step 2 script only - not sure if we will get an error 
# at any other steps where its not valid... 

extra_flags=

# had these for Carsten, removed here - did not show up in GUI log following the screenshot sent.
#"--int-removal 0 --peak-center --no-ifs-removal --scanning-swath"

#-----

# Accounting:

# NCI project code for billing: 
project=

# NCI lstorage paths for IO:
lstorage=" "

#-----

# dot wine tar folder with DiANN.exe installed

wine_tar=<dot_wine.tar>

#-----

# wine singularity container 

wine_image=<wine_sif>

#-----

# diann singularity container
# only required for step 1 - if you are performing a true library free, leave as na
# or else update path to diann_v1.8.1_cv1.sif: 

diann_image=


#### END OPTION SETTING ####
########################################
#--------------------------------------------------------------------------------

# Make required workflow directories:
mkdir -p Logs PBS_logs Inputs Raw_data

for wiff in `find -L ${wiff_dir} -name "*.wiff" -exec realpath -s {} \;`
do
	wiff_base=$(basename $wiff)
	if [ ! -L Raw_data/${wiff_base} ]
	then
		ln -s $wiff Raw_data/
	fi
	if [ ! -L Raw_data/${wiff_base}.scan ]
	then
		ln -s ${wiff}.scan Raw_data/
	fi
done
n=$(ls -1 Raw_data/*wiff | wc -l)

#--------------------------------------------------------------------------------
# PBS stuff - accounting, storage and logs

# Update project and storage: 
sed -i "s|^#PBS -P.*|#PBS -P ${project}|g" ./Scripts/*pbs
sed -i "s|^#PBS -l[ ]*storage.*|#PBS -l storage=${lstorage}|g" ./Scripts/*pbs


# Update PBS log output file names according to number of samples:  
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
# Setup window, mass acc and MS1 acc parameters based on user input:

if [[ $subsample == 'true' ]]
then 
	printf "SUBSAMPLING:\n\t* Selecting ${percent}%% of samples from ${wiff_dir} for subsampling\n"
	
	# Run the subsample selector:
	list=Inputs/2_preliminary_analysis_subsample.list
	subsampled=$(perl Scripts/2_select_subsamples.pl $percent $n $list)
	printf "\t* ${subsampled} samples from total cohort of $n written to ${list}\n\n";
	
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

printf "SCAN WINDOW AND MASS ACCURACIES:\n"
if [[ $scan_window  =~ ^[0-9]+$ ]]
then  
	windows="--window ${scan_window}"
	printf "\t* Applying fixed scan window parameter:\n\t${windows}\n\n"
elif [[ $scan_window  =~ ^auto$ ]]
then
	windows="--individual-windows"
	printf "\t* Applying automatic scan window parameter:\n\t${windows}\n\n"
else
	printf "Sorry, ${scan_window} not an accepted value for scan_window - please specify an integer or 'auto'\n\n"
	exit
fi

### Mass accuracy (MS2 acc)  
if [[ $mass_acc  =~ ^[0-9.]+$ ]]
then  
	printf "\t* Applying fixed mass accuracy parameter:\n\t--mass-acc ${mass_acc}\n\n"
elif [[ $mass_acc  =~ ^auto$ ]]
then
	printf "\t* Applying automatic mass accuracy parameters:\n\t--individual-mass-acc --quick-mass-acc\n\n"
else
	printf "Sorry, ${mass_acc} not an accepted value for mass_acc - please specify a number or 'auto'\n\n"
	exit
fi

### MS1 mass accuracy 
if [[ $ms1_acc  =~ ^[0-9.]+$ ]]
then  
	printf "\t* Applying fixed MS1 mass accuracy parameter:\n\t--mass-acc-ms1 ${ms1_acc}\n\n"
elif [[ $ms1_acc  =~ ^auto$ ]]
then
	printf "\t* Not specifying fixed MS1 mass accuracy\n\n"
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
# Update fasta (all steps):
### update 21/12/23: added steps 2 and 3 to the list of scripts with fasta
### it makes no sense to leave them off... i cant find anything in ~ 70 pages of notes as to why  

# first, split out multiple fastas:
if [[ $fasta =~ ',' ]]
then
	IFS=', ' read -r -a array <<< "$fasta"
	for i in ${array[@]}
	do 
		fasta_var_string+="--fasta $i "
	done
else
	fasta_var_string="--fasta $fasta"
fi


scripts_to_update="Scripts/1_generate_insilico_lib.pbs  Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis_make_input.sh Scripts/5_summarise.pbs"
sed -i "s|^fasta_var_string=.*|fasta_var_string=\"${fasta_var_string}\"|g" $scripts_to_update


#--------------------------------------------------------------------------------
# Library free or library based

# For 'library free', user has entered 'auto' at spectral_lib, and in this case, a fasta digest (step 1) needs to occur
# For 'library based', user has entered the filepath of an experimentally generated library file
# Can DIA-NN accept TWO LIBS? Must test this before proceeding! --> yes it can , but you get a warning that
# its experimental, so not pursuing that for now. 


# script needs to accomodate 3 options:
# - 1) use an experimental lib, no digest required
# - 2) perform a fasta digest and use that lib
# - 3) perform a fasta digest on a fasta AND an experimental lib 


printf "STEP 1:\n"

if [[ $insilico_lib_prefix != 'false' ]]
then
	# update the diann singularity image name in the step 1 script:
	# Linux diann is used for step 1, as the results are the same and its very much faster 
	sed -i "s|^diann_image=.*|diann_image=${diann_image}|g" Scripts/1_generate_insilico_lib.pbs
	
	# insilico_lib_prefix  used to name the created library, since multiple fasta option precludes using fasta prefix as outfile name:.
	sed -i "s|^insilico_library_prefix=.*|insilico_library_prefix=${insilico_lib_prefix}|g" Scripts/1_generate_insilico_lib.pbs
		
	# update the library name in the downstream script:
	scripts_to_update="Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs"
	insilico_lib=1_insilico_library/${insilico_library_prefix}.predicted.speclib
	sed -i "s|^spectral_lib=.*|spectral_lib=${insilico_lib}|g" $scripts_to_update
	
	if [[ $spectral_lib == 'false' ]]
	then
		# Option 2: insilico digest, fasta only  
		printf "\t* A spectral library will be predicted in-silico using ${fasta}\n"
		printf "\t* Please run Scripts/1_generate_insilico_lib.pbs after setup is complete.\n"
		printf "\t* Once the in-silico library has been created, continue to step 2.\n"
		
		lib_flags=""

	elif [[ -s $spectral_lib ]]
	then
		# Option 3: insilico digest, use fasta AND experimental speclib ("belts and braces") 
		printf "\t* A spectral library will be predicted in-silico using ${fasta} and ${spectral_lib}\n"
		printf "\t* Please run Scripts/1_generate_insilico_lib.pbs after setup is complete.\n"
		printf "\t* Once the in-silico library has been created, continue to step 2.\n"		

		lib_flags="--lib ${spectral_lib}"
		
	else
		printf "ERROR: spectral_lib variable should be set to 'false' or a valid spectral library.\n"
		printf "Please check setup script and resubmit. Exiting.\n"
		exit
	fi
else 
	if [[ -s $spectral_lib ]]
	then
		# Option 1: use pre-generated experimental spectral lib as input for steps 2 and 3:
		printf "\t* Step 1 creates an in-silico library from proteome fasta.\n"
		printf "\t* You have supplied $spectral_lib so no fasta digest needs to be performed.\n"
		printf "\t* Please skip step 1 and commence with step 2\n"
		scripts_to_update="Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs"
		sed -i "s|^spectral_lib=.*|spectral_lib=${spectral_lib}|g" $scripts_to_update
	
		# use spectral lib file prefix in empirical_lib (step 3) outfile name: 
		empiical_lib_prefix=${spectral_lib%%.*}

		lib_flags=""
		
	else
		printf "ERROR: You have set insilico_lib_prefix to false, so a spectral library file  must be specified.\n"
		printf "You have supplied spectral library file $spectral_lib, which does not exist or has zero bytes.\n"
		printf "Please check setup script and resubmit. Exiting.\n"
		exit
	fi
fi

# Add or remove spectral library flags from step 1 script as required:
sed -i "s|^extra_flags=.*|extra_flags=\"${lib_flags}\"|g" Scripts/1_generate_insilico_lib.pbs


#--------------------------------------------------------------------------------
# Update empirical library name - this library is cohort specific and is produced based on
# the actual samples present, the fasta, and the spectral library either in-silico or experimental:
# Empirical lib (ie cohort specific) is used as output for step 3 and input for steps 4 and 5: 

empirical_lib=${cohort}_${n}s.empirical

scripts_to_update="Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis_make_input.sh Scripts/5_summarise.pbs"
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
scripts_to_update="Scripts/1_generate_insilico_lib.pbs Scripts/2_preliminary_analysis_make_input.sh Scripts/3_assemble_empirical_lib.pbs Scripts/4_individual_final_analysis_make_input.sh Scripts/5_summarise.pbs"
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
	printf "\nINPUTS FOR PARALLEL STEPS 2 AND 4:\n"
	printf "\t* "
	bash Scripts/2_preliminary_analysis_make_input.sh
	printf "\t* "
	bash Scripts/4_individual_final_analysis_make_input.sh
else	
	printf "\nSTEP 2:\n\t* Please update resources in Scripts/2_preliminary_analysis_run_parallel.pbs for ${subsampled} samples, then submit.\n"
	printf "\t* After this job has successfully completed, please run Scripts/2_subsample_averages.pl\n"
	printf "\t* Then continue with the workflow, starting with Scripts/2_preliminary_analysis_run_parallel.pbs\n"
	printf "\t* The subsampling averages script will also create the inputs file for step 4.\n\n"
fi
#---------------------------------------
