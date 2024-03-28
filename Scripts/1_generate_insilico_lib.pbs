#!/bin/bash

# Create in-silico spectral library from proteome fasta

#---------------------------- 

#---------------------------- 

#PBS -P <project>
#PBS -N step1
#PBS -l ncpus=24
#PBS -l walltime=01:20:00
#PBS -l mem=90GB
#PBS -q express
#PBS -l wd
#PBS -o ./PBS_logs/step1_gen_insilico_lib.o
#PBS -e ./PBS_logs/step1_gen_insilico_lib.e
#PBS -l storage=<lstorage>


module load singularity

set -e

#---------------------------- 

#---------------------------- 
# I/O (hard-coded, please do not change) 

out_dir=1_insilico_library

mkdir -p ${out_dir}

#---------------------------- 

#----------------------------
# Inputs auto-updated when the setup script is run:

# DIA-NN resources:
diann_image=<path_to_diann_v1.8.1_cv1.sif>

# Proteome fasta for study species. Must have .fasta or .fa suffix
fasta_var_string=" "

# insilico library prefix. Since more than one fasta can be provided, can't use fasta prefix. User must specify. 
insilico_lib_prefix=<prefix>

#----------------------------

#----------------------------  
 
# Run DIA-NN Linux CLI version with singularity

### Digest parameter flexibility will be added when the workflow is nextflowed 

extra_flags=""

singularity exec \
        ${diann_image} \
        diann \
	--threads ${PBS_NCPUS} \
	--verbose 4 \
	--out-lib ${out_dir}/${insilico_lib_prefix}.lib \
	--gen-spec-lib \
	--predictor \
	--reannotate \
	${fasta_var_string} \
	--fasta-search \
        --min-fr-mz 200 \
        --max-fr-mz 1800 \
        --met-excision \
        --cut K*,R* \
        --missed-cleavages 1 \
        --min-pep-len 7 \
        --max-pep-len 30 \
        --min-pr-mz 400 \
        --max-pr-mz 900 \
        --min-pr-charge 1 \
        --max-pr-charge 4 \
        --unimod4 \
	${extra_flags} > Logs/1_generate_insilico_lib.log 2>&1
	
#-----------------------------------------
