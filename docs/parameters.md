## Parameters

Please refer to the [DIA-NN documentation - command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference) for parameters. **Note that the DIA-NN CLI defaults are not the same as the GUI and you should explicitly set parameters**. Also note that the GUI defaults have changed between DIA-NN versions 1.8.0 and v 1.8.1. 

Some parameters are hard-coded within this workflow and some are specified by the user within a setup script. Within the setup script is an `extra_flags` parameter that can be used to add any of DIA-NN's many flags to the workflow. Note that anything provided in `extra_flags` will be added to ALL steps in the workflow, and we have not tested every possible combination of flags. As such, it may be possible to encounter errors or warnings if a flag has been applied to a DIA-NN step for which it is not valid.

Parameters which have been hard-coded (may change when Nextflowed):

- `rt-profiling` (smart profiling yielded no benefit for a much slower run time) 
- `pg-level 2`
- `qvalue 0.01` 

At the time of writing, we have tested the following extra flags:

- `int-removal 0`
- `peak-center`
- `no-ifs-removal`
- `scanning-swath`

By adding `--int-removal 0`, `--peak-center` and `--no-ifs-removal`, this best matches the defaults from the GUI v 1.8.0 when:

-  quantification strategy is selected as `Any LC (high accuracy)`
-  `MBR`, `reannotate`, `fasta digest` and `deep learning` are checked
- `heuristic protein inference` and `no shared spectra` are unchecked  

The `scanning-swath` parameter should be applied if the data was generated as Scanning SWATH. When running the DIA-NN GUI, this is detected automatically - note that this is NOT the case when running this workflow. 