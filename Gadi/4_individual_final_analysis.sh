#!/bin/bash

# Averaged recommended settings for this experiment: Mass accuracy = 16ppm, MS1 accuracy = 20ppm, Scan window = 7

diannImg=`echo $1 | cut -d ',' -f 1`
lib=`echo $1 | cut -d ',' -f 2`
mzML=`echo $1 | cut -d ',' -f 3`
temp=`echo $1 | cut -d ',' -f 4`
logDir=`echo $1 | cut -d ',' -f 5`

singularity exec ${diannImg} diann \
        --f ${mzML} \
        --lib ${lib} \
        --threads ${NCPUS} \
        --verbose 4 \
        --temp ${temp} \
        --mass-acc 16 \
        --mass-acc-ms1 20 \
        --window 7 \
        --no-ifs-removal \
        --no-main-report \
        --no-prot-inf \
	--out $(basename ${mzML%%.*}) >${logDir}/$(basename ${mzML%%.*}).log 2>&1 

