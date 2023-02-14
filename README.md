# DiaNN 

<p align="center">
:wrench: This pipeline is currently under development :wrench:
</p>

This workflow implements the Linux/CLI installation of [DIA-NN](https://github.com/vdemichev/DiaNN) in a highly scalable fashion. DIA-NN is a tool that performs data processing and analysis for data-independant acquistion (DIA) proteomics data and was originally developed by Demichev, Ralser and Lilley Labs ([Ralser et al. 2020](https://www.nature.com/articles/s41592-019-0638-x)).

Please note:
* This workflow breaks up the linux command line `diann` tool into a series of jobs. We followed the steps recommended by the primary developers of DIA-NN and [quantms](https://quantms.readthedocs.io/en/latest/), described in this [Github issue #164](https://github.com/bigbio/quantms/issues/164)
* Some of these jobs were amenable to parallelisation. Running tasks in parallel using `nci-parallel` and adjusting compute request to size of the job is how scale is achieved.
* Refer to the [DIA-NN documentation - command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference) for parameters. **Note that the DIA-NN CLI defaults are not the same as the GUI and you should explicitly set parameters**
* [quantms](https://quantms.readthedocs.io/en/latest/) is intended to be a scalable nextflow workflow of DIA-NN, but currently does not work on NCI Gadi or Pawsey Nimbus (suspect that it is due to MacOS vs Linux incompatibilities) and hence this workflow was re-created here

## Infrastructure

Please refer to the user guide for the infrastructure you are using:

- [NCI Gadi](https://github.com/Sydney-Informatics-Hub/DiaNN/blob/main/Gadi.md)
- [Ronin/AWS](https://github.com/Sydney-Informatics-Hub/DiaNN/blob/main/RoninAWS.md)