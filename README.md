# Scalable DIA-NN 

## Overview

This workflow implements the CLI installation of [DIA-NN](https://github.com/vdemichev/DiaNN) in a highly scalable fashion. DIA-NN is a popular tool that performs data processing and analysis for data-independent acquistion (DIA) proteomics data and was developed by Demichev, Ralser and Lilley Labs ([Ralser et al. 2020](https://www.nature.com/articles/s41592-019-0638-x)).

Native DIA-NN is designed to utilise up to all cores on a single node, and does not currently have multi-node capability. For experiments with high numbers of samples, processing DIA data can be time-consuming and require batch processing followed by batch correction. This workflow has been created to enable large sample cohorts to be analysed with DIA-NN as a single batch on HPC, thereby eliminating batch effects (Fig. 1) and vastly reducing compute walltime (Fig. 2). We have achieved speedups of 61X and 145X on large cohort Scanning SWATH and Zeno SWATH datasets, respectively. 

<figure>
    <img src=.figs/batch_effects.png width="75%" height="75%">
    <figcaption><b>Fig.1 a.</b>  Batch-processing of 1530 Scanning SWATH samples over 10 batches using DIA-NN GUI on PC.  <b>b.</b> Processing the same 1530 samples using this Scalable-DIA-NN workflow on HPC. </figcaption>
</figure>  


</br></br>

<figure>
    <img src=.figs/speedup.png width="75%" height="75%">
    <figcaption><b>Fig.2</b> Comparison of compute between PC GUI DIA-NN and Scalable-DIA-NN over two large-cohort datasets.</figcaption>
</figure>  


</br></br>


To tease apart the DIA-NN run command into discrete jobs, we followed the steps recommended by the primary developers of DIA-NN and [quantms](https://quantms.readthedocs.io/en/latest/), described in this [Github issue](https://github.com/bigbio/quantms/issues/164). Quantms is a scalable nextflow workflow of DIA-NN, but currently does not work on NCI Gadi or Pawsey Nimbus (suspect that it is due to MacOS vs Linux incompatibilities) and hence this workflow was re-created here.

Importantly, our workflow differs from quantms as it takes .wiff files as input,  where quantms requires mzML input. Converting .wiff files to the universal mzML format has two important downsides:

- Converting wiff to mzML requires 1-2 hours compute per sample and necessitates a double-up of raw data stored
- We have found susbstantial [deleterious impacts on the results](https://github.com/vdemichev/DiaNN/issues/777) when processing the same samples from wiff or mzML format with identical run parameters

To avoid the use of mzML, we use the Windows version of DIA-NN on Linux by executing with Wine (a PC emulator). We have installed Windows DIA-NN v. 1.8.1 with Wine 7 and packaged this into an archive; see [Obtain required input files](./docs/detailed-user-guide.md#obtain-required-input-files) under [Detailed user guide](./docs/detailed-user-guide.md). We developed this workflow on [NCI Gadi HPC](https://nci.org.au/our-systems/hpc-systems), which has a Lustre scratch filesystem. We found we were unable to execute PC DIA-NN with Wine when the installation folder was on Lustre, so the workflow copies the archive to the solid-state local-to-the-node storage for each task.

For more details on the workflow, see the topics below:

- [Portability](./docs/portability.md)
- [Compute usage](./docs/compute-usage-examples.md)
- [CPU efficiency](./docs/cpu-efficiency.md)
- [Parameters](./docs/parameters.md)
- [Input requirements](./docs/input-requirements.md)
- [Overview of workflow steps](./docs/overview-of-workflow-steps.md)
- [Library method options](./docs/library-method-options.md)
- [Detailed user guide](./docs/detailed-user-guide.md)



