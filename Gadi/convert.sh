#!/bin/bash

pwiz=`echo $1 | cut -d ',' -f 1`
wiff=`echo $1 | cut -d ',' -f 2`
outdir=`echo $1 | cut -d ',' -f 3`
logdir=`echo $1 | cut -d ',' -f 4`

singularity run --env WINEDEBUG=-all \
	-B /scratch/:/scratch \
	${pwiz} wine msconvert \
	${wiff} \
	--32 \
	--filter "peakPicking vendor msLevel=1-" \
	-o ${outdir} \
	--outfile $(basename ${wiff%%.*}).mzML >${logdir}/$(basename ${wiff%%.*}).log 2>&1
