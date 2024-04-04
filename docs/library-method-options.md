### Library method options

This workflow has three library options:

#### 1. Library-based

A cohort-specific, experimentally generated spectral library is available for the experiment. 

To perform a library-based analysis, library settings for the parameter configuration performed at step 0 will be:

``` 
insilico_lib_prefix=false
spectral_lib=<filepath of experimental spectral library>
```

Step 1 of the workflow is skipped. 

#### 2. Library-free

No cohort-specific, experimentally generated spectral library is available for the experiment, so an in-silicio spectral library created from a digest of the proteome fasta is required. 

To perform library-free analysis, library settings for the parameter configuration performed at step 0 will be:

```
insilico_lib_prefix=<desired library prefix name>
spectral_lib=false
```

Step 1 of the workflow is required.

#### 3. Belt-and-braces

To use *both* a proteome fasta and a cohort-specific experimentally generated spectral library to produce the insilico library, apply the following settings at step 0:

```
insilico_lib_prefix=<desired library prefix name>
spectral_lib=<filepath of experimental spectral library>
```

Step 1 of the workflow is required. 

Note that this is NOT a recommended strategy from the DIA-NN developers, but it is a valid run method for the GUI so we have enabled it here. Preliminary tests with our data have found no benefit in running in this way compared to library-free. On a 146-sample cohort, we found actually fewer unique genes in the final matrix (2753) compared to library-based (2945) and library-free (2974). This was surprising, given the library was slightly larger when created from both the experimental spectral library plus fasta.   

#### Library choice

Library-free analysis is [recommended by DIA-NN developers](https://github.com/vdemichev/DiaNN?tab=readme-ov-file#library-free-search) for most experiments.

We compared library-free vs library-based for the 1530-sample cohort referenced in Figs 1 and 2. The final unique genes matrix contained 3386 genes in library-free mode and 2846 in library-based. After removing genes not detected in >30% samples, the library-free method produced 3078 genes and the library-based was 2813.