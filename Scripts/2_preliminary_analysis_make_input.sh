#/bin/bash

# Create list of commands to execute 2_preliminary_analysis.sh in parallel
# This script does not normally require editing directly


#---------------------------- 

#---------------------------- 
# Inputs auto-updated when the setup script is run:

dia_suffix=raw

wine_tar=/scratch/er01/PIPE-3050-DIA-NN/thermo_raw/diann_resources/dot_wine_DIANN_SCIEX_THERMO.tar
wine_image=/scratch/er01/PIPE-3050-DIA-NN/thermo_raw/diann_resources/wine_7.0.0.sif
spectral_lib=1_insilico_library/human_UP000005640_9606.predicted.speclib
fasta_var_string="--fasta /scratch/er01/PIPE-3050-DIA-NN/thermo_raw/human_proteome/UP000005640_9606.fasta --fasta /scratch/er01/PIPE-3050-DIA-NN/thermo_raw/human_proteome/UP000005640_9606_additional.fasta "

scan_window=auto
mass_acc=auto
ms1_acc=0

#---------------------------- 

#----------------------------
# I/O (hard-coded, please do not change):

inputs=Inputs/2_preliminary_analysis.inputs
log_dir=Logs/2_preliminary_analysis
temp=2_quant

mkdir -p  ${log_dir} ${temp}
rm -rf ${inputs}


#---------------------------- 

#----------------------------
# Write inputs file, one line per sample:
# find -L and realpath -s to ensure symbolic links and sub-directories are treated appropriately 

for file in `ls Raw_data/*.${dia_suffix}`
do
	echo "${wine_tar},${wine_image},${spectral_lib},${file},${temp},${log_dir},${scan_window},${mass_acc},${ms1_acc},\"${fasta_var_string}\",${dia_suffix}" >> ${inputs}	
done

echo Inputs for `wc -l < ${inputs}` samples written to ${inputs} 
