#!/bin/bash

diannImg=`echo $1 | cut -d ',' -f 1`
lib=`echo $1 | cut -d ',' -f 2`
mzML=`echo $1 | cut -d ',' -f 3`
temp=`echo $1 | cut -d ',' -f 4`
logDir=`echo $1 | cut -d ',' -f 5`

singularity exec ${diannImg} \
	diann --verbose 4 \
	--individual-windows \
	--min-corr 2.0 \
	--corr-diff 1.0 \
	--quick-mass-acc \
	--individual-mass-acc \
	--time-corr-only \
	--lib ${lib} \
	--f ${mzML} \
	--threads ${NCPUS} \
	--temp ${temp} \
	--out ./2_preliminary_analysis.report.tsv >${logDir}/$(basename ${mzML%%.*}).log 2>&1
