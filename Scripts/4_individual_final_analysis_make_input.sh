#/bin/bash


# The below 3 values can be automatically updated by running 4_individual_final_analysis_setup.pl
# This script will extract these values from the step 3 log, update them here, then submit this script
# This script can be run manually without  4_individual_final_analysis_setup.pl if different values are desired to be used
# The below values are updated when setup_scripts.sh is run. There is nothing to be changed.

#---------------------------- 

#---------------------------- 
# Inputs auto-updated when the setup script is run:

dia_suffix=raw
wine_tar=/scratch/er01/PIPE-3050-DIA-NN/thermo_raw/diann_resources/dot_wine_DIANN_SCIEX_THERMO.tar
wine_image=/scratch/er01/PIPE-3050-DIA-NN/thermo_raw/diann_resources/wine_7.0.0.sif
empirical_lib=PXD050996_71s.empirical
fasta_var_string="--fasta /scratch/er01/PIPE-3050-DIA-NN/thermo_raw/human_proteome/UP000005640_9606.fasta --fasta /scratch/er01/PIPE-3050-DIA-NN/thermo_raw/human_proteome/UP000005640_9606_additional.fasta "

scan_window=auto
mass_acc=auto
ms1_acc=0

#---------------------------- 

#---------------------------- 
# I/O (hard-coded, please do not change) 

temp=4_quant # output quant files
libdir=3_empirical_library # lib made at step 3
inputs=Inputs/4_individual_final_analysis.inputs
log_dir=Logs/4_individual_final_analysis

mkdir -p ${log_dir} $temp
rm -rf ${inputs}


#---------------------------- 

#---------------------------- 
# Create parallel inputs file:

for file in `ls Raw_data/*.${dia_suffix}`
do
	echo "${wine_tar},${wine_image},${empirical_lib},${file},${temp},${log_dir},${scan_window},${mass_acc},${ms1_acc},\"${fasta_var_string}\",${dia_suffix}" >> ${inputs}
done

printf "Inputs for `wc -l < ${inputs}` samples written to ${inputs}\n"

#-----------------------------------------
