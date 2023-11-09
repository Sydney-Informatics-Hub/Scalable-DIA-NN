#!/bin/bash

# Run this script after step 2 completes, 2 check for
# failed tasks and if found, write a new inputs with 
# failed tasks to be rerun with 
# Scripts/2_preliminary_analysis_run_parallel_failed.pbs

#----------------------------

#---------------------------- 
# Auto-updated from setup script:

subsample=<value>

# Use of ls rather than direct variable so that the same 
# check script can be used for subsample or full step 2 run
# Assumption: that the log to query is the latest created

log_prefix=<value>

o_log=$(ls -lhtr PBS_logs/$log_prefix*.o | tail -1 | awk '{print $9}')
e_log=$(ls -lhtr PBS_logs/$log_prefix*.e | tail -1 | awk '{print $9}')


#----------------------------

#---------------------------- 
# Hardcoded 
inputs=Inputs/2_preliminary_analysis.inputs
log_dir=Logs/2_preliminary_analysis
quant_dir=2_quant

if [[ $o_log = *failed* ]]
then
	inputs=Inputs/2_preliminary_analysis.inputs-failed
fi


#----------------------------

#----------------------------
# Check the inputs file is not empty

if ! [[ -s $inputs ]]
then 
	printf "ERROR: ${inputs} is missing or empty\n"
	printf "This liklely means the whole job failed. Please investigate and re-submit the job.\n"
	exit
fi


#----------------------------

#---------------------------- 
# Check the parent job exit status

all_exit=$(grep "Exit" ${o_log} | awk '{print $3}')
printf "Checking exit status in ${o_log}: "
if [[ $all_exit -eq 0 ]]
then
	printf "Parent job exit status OK\n"
else 
	printf "ERROR: Parent job exit status ${all_exit}\n\n"	
fi


#----------------------------

#---------------------------- 
# Check the .e log for task exit status

printf "Checking log ${e_log}:\n"
failed_samples=()
while read TASK
do
	# will only return true if exit status is 0
	task_exit=$( grep $TASK $e_log | grep "exited with status 0")
	if ! [[ $task_exit ]]
	then
		sample=$( echo $TASK | cut -d ',' -f 4 | xargs basename | sed 's/\.wiff//')
		printf "\tERROR: non-zero exit status for ${sample} task\n"
		failed_samples+=(${sample})
	fi
done < ${inputs}

if [[ ${#failed_samples[@]} < 1 ]]
then
	printf "\tAll samples task exit 0\n"
fi


#----------------------------

#---------------------------- 
# Check each sample's output files

printf "Checking quant, report, log and stats outputs:"
while read LINE
do
	wiff=$(echo $LINE | cut -d ',' -f 4)
	sample=$(basename ${wiff%.wiff})
		
	quant=${quant_dir}/$( echo $wiff | sed 's|/|_|g' | sed 's|\.wiff|\_wiff\.quant|')
	oe_log=${log_dir}/${sample}.oe
	report=${log_dir}/${sample}.report.tsv
	stats=${log_dir}/${sample}.report.stats.tsv
	run_log=${log_dir}/${sample}.report.log.txt
	
	out_files=( $quant $oe_log $report $stats $run_log )
	error=0
	
	for file in ${out_files[@]}
	do 
		if ! [[ -s $file ]]
		then 
			printf "ERROR: ${file} is missing or zero bytes\n"
			((error+=1))
		fi
	
	done
	
	if ! grep -q Finished ${oe_log}
	then 
		printf "ERROR: ${oe_log} is missing 'Finished' status\n"
		((error+=1))	                     
	fi			
		
	if [[ $error -gt 0 ]]
	then
		failed_samples+=(${sample})
	fi

done < ${inputs}


#----------------------------

#---------------------------- 
# Print new inputs list for failed samples

uniq_err_samples=($(for s in "${failed_samples[@]}"; do echo "${s}"; done | sort -u))

failed=${inputs}-temp-failed
rm -rf ${failed}

if [[ ${#uniq_err_samples[@]} -gt 0 ]]
then

	printf "\n\nWriting `echo ${#uniq_err_samples[@]}` failed tasks to ${inputs}-failed for the following samples:\n"

	for sample in ${uniq_err_samples[@]}
	do
		printf "\t${sample}\n"
		grep ${sample} ${inputs} >> ${failed}
     
	done
	
	# Use of a temp failed in case of checking a failed resubmit
	mv $failed ${inputs}-failed
	
	printf "\n\n* Errors detected: Please update resources in Scripts/2_preliminary_analysis_run_parallel_failed.pbs and submit.\n\n" 

else
	printf " All samples outputs passed\nNo issues detected\n"
	
	if [[ $subsample == 'true' ]] && [[ $o_log = *Subsample* ]]
	then
		printf "\n* Please run 'perl Scripts/2_subsample_averages.pl'\n\n"
	else
		printf "\n* Please adjust resources in Scripts/3_assemble_empirical_lib.pbs and submit\n\n"
	fi
fi


#-----------------------------------------
