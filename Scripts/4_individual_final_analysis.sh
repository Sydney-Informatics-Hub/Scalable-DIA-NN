#!/bin/bash

# Do not edit this script directly


#---------------------------- 

#---------------------------- 
# Variables from inputs file

wine_tar=`echo $1 | cut -d ',' -f 1`
wine_image=`echo $1 | cut -d ',' -f 2`
empirical_lib=`echo $1 | cut -d ',' -f 3`
wiff=`echo $1 | cut -d ',' -f 4`
temp=`echo $1 | cut -d ',' -f 5`
log_dir=`echo $1 | cut -d ',' -f 6`
scan_window=`echo $1 | cut -d ',' -f 7`
mass_acc=`echo $1 | cut -d ',' -f 8`
ms1_acc=`echo $1 | cut -d ',' -f 9`
fasta_var_string=`echo $1 | cut -d ',' -f 10`

sampleID=$(basename ${wiff%.wiff})


#---------------------------- 

#----------------------------
# Add the scan window and 2 mass acc params into one string

if [[ $scan_window  =~ ^[0-9]+$ ]]
then  
        windows="--window ${scan_window}"
elif [[ $scan_window  =~ ^auto$ ]]
then
        windows="--individual-windows"
fi

if [[ $mass_acc  =~ ^[0-9.]+$ ]]
then  
        massacc="--mass-acc ${mass_acc}"
elif [[ $mass_acc  =~ ^auto$ ]]
then
        massacc="--individual-mass-acc --quick-mass-acc"
fi

massacc_and_windows="${windows} ${massacc}"

if [[ $ms1_acc =~ [1-9] ]] # Setup script ensures ms1_acc can only match numbers so can use this relaxed pattern here safely to easily bypass zero while allowing for non-integers
then
        massacc_and_windows+=" --mass-acc-ms1 ${ms1_acc}"
fi


#---------------------------- 

#----------------------------
# Private dot_wine required for each task

jobfs=${PBS_JOBFS}/${sampleID} 
mkdir ${jobfs}
tar xf ${wine_tar} -C ${jobfs} 
WINEPREFIX=${jobfs}/dot_wine
diann_exe=${WINEPREFIX}/drive_c/DIA-NN/1.8.1/DiaNN.exe


#---------------------------- 

#----------------------------
# Run DiaNN.exe with Wine singularity container

extra_flags=""

libdir=3_empirical_library

singularity exec \
        --env WINEPREFIX=${WINEPREFIX} \
        --env WINEDEBUG=-all \
        ${wine_image} \
        wine \
        ${diann_exe} \
	--verbose 4 \
	--lib ${libdir}/${empirical_lib} \
	--f ${wiff} \
	${fasta_var_string} \
	--threads ${NCPUS} \
	--temp ${temp} \
	${massacc_and_windows} \
	--out ${log_dir}/${sampleID}.report.tsv \
	${extra_flags} > ${log_dir}/${sampleID}.oe 2>&1

#-----------------------------------------
