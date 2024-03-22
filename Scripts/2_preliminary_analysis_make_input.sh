#/bin/bash

# Create list of commands to execute 2_preliminary_analysis.sh in parallel
# This script does not normally require editing directly


#---------------------------- 

#---------------------------- 
# Inputs auto-updated when the setup script is run:

wine_tar=<dot_wine.tar>
wine_image=<wine_sif>
spectral_lib=<speclib>
fasta_var_string=" "

scan_window=<value>
mass_acc=<value>
ms1_acc=<value>

#---------------------------- 

#----------------------------
# I/O (hard-coded, please do not change):

wiff_dir=Raw_data
inputs=Inputs/2_preliminary_analysis.inputs
log_dir=Logs/2_preliminary_analysis
temp=2_quant

mkdir -p  ${log_dir} ${temp}
rm -rf ${inputs}


#---------------------------- 

#----------------------------
# Write inputs file, one line per sample:
# find -L and realpath -s to ensure symbolic links and sub-directories are treated appropriately 

for wiff in `ls ${wiff_dir}/*wiff`
do
	echo "${wine_tar},${wine_image},${spectral_lib},${wiff},${temp},${log_dir},${scan_window},${mass_acc},${ms1_acc},\"${fasta_var_string}\"" >> ${inputs}	
done

echo Inputs for `wc -l < ${inputs}` samples written to ${inputs} 
