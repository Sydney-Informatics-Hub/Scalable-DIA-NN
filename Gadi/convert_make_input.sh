#/bin/bash

# Set up to use pwiz.sif to convert .wiff files to .mzML format
# Create list of commands to execute in parallel

# To run: sh ./convert.sh

# CHANGE VARIABLES 
pwiz=pwiz.sif
wiffDir=pilot_data
outDir=Expanded_mzML

# SCRIPT (do not change)
inputDir=./Inputs
logDir=./Logs/convert

mkdir -p ${outDir} ${inputDir} ${logDir}
rm -rf ${inputDir}/convert.txt

for wiff in `ls -d ${wiffDir}/*.wiff`; do
	echo "${pwiz},${wiff},${outDir},${logDir}" >> ${inputDir}/convert.txt
done
