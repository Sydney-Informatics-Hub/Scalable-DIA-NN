## CPU efficiency

This workflow has fairly poor CPU efficiency, in part to do with DIA-NN itself (which was not written to be parallelised in this way) and in part due to running a PC tool under Wine on a Linux platform. Tasks have approximately double walltime compared to when running Linux DIA-NN on mzML input. However, walltime, KSU and disk is saved from not requiring the wiff &rarr; mzML conversion step, as well as the [improvement in results](https://github.com/vdemichev/DiaNN/issues/777) when using wiff input. 

Updating to a Wine 8 container (currently using 7.0.0) may also help, and remains a plan for future testing. 