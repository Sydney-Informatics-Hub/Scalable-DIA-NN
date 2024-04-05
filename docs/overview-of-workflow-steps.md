## Overview of workflow steps

**Environment setup:** Clone the repository and establish required input files

**0. Parameter setup:** provide parameters in a parameters text file and then run the setup script to update parameters to the whole workflow

**1. Optional in-silico library creation:** see [Library method options](./library-method-options.md)

**2. Parallel initial quantification of samples**, using the in-silico library, experimentally-generated spectral library, or both 

**3. Creation of cohort-specific empirical library**

**4. Parallel final quantification of samples**, using the cohort-specific empirical library 

**5.  Creation of gene matrix and statistics output files**

**6.  Optional filtering** step to remove genes with high missing values