#/bin/bash

# Set up to use pwiz.sif to convert .wiff files to .mzML format
# Create list of commands to execute in parallel

# To run: sh ./preliminary_analysis_make_input.sh

# CHANGE VARIABLES
diannImg=biocontainers-diann-v1.8.1_cv1.img
lib=mouse_proteome.predicted.speclib
mzMLDir=Expanded_mzML_complete

# SCRIPT (do not change)
inputDir=./Inputs
logDir=./Logs/2_preliminary_analysis
temp=./quant

mkdir -p ${inputDir} ${logDir} ${temp}
rm -rf ${inputDir}/2_preliminary_analysis.txt

for mzML in `ls -d ${mzMLDir}/*.mzML`; do
	echo "${diannImg},${lib},${mzML},${temp},${logDir}" >> ${inputDir}/2_preliminary_analysis.txt
done
