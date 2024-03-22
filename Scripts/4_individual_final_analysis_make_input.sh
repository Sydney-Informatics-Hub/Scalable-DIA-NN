#/bin/bash


# The below 3 values can be automatically updated by running 4_individual_final_analysis_setup.pl
# This script will extract these values from the step 3 log, update them here, then submit this script
# This script can be run manually without  4_individual_final_analysis_setup.pl if different values are desired to be used
# The below values are updated when setup_scripts.sh is run. There is nothing to be changed.

#---------------------------- 

#---------------------------- 
# Inputs auto-updated when the setup script is run:

wine_tar=<dot_wine.tar>
wine_image=<wine_sif>
empirical_lib=<empirical_lib>
fasta_var_string=" "

scan_window=<value>
mass_acc=<value>
ms1_acc=<value>

#---------------------------- 

#---------------------------- 
# I/O (hard-coded, please do not change) 

wiff_dir=Raw_data
temp=4_quant # output quant files
libdir=3_empirical_library # lib made at step 3
inputs=Inputs/4_individual_final_analysis.inputs
log_dir=Logs/4_individual_final_analysis

mkdir -p ${log_dir} $temp
rm -rf ${inputs}


#---------------------------- 

#---------------------------- 
# Create parallel inputs file:

for wiff in `ls ${wiff_dir}/*wiff`
do
	echo "${wine_tar},${wine_image},${empirical_lib},${wiff},${temp},${log_dir},${scan_window},${mass_acc},${ms1_acc},\"${fasta_var_string}\"" >> ${inputs}
done

printf "Inputs for `wc -l < ${inputs}` samples written to ${inputs}\n"

#-----------------------------------------
