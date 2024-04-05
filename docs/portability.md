## Portability

This workflow uses `nci-parallel` utility to parallelise processing across the NCI Gadi cluster. As such, it curently works out of the box only on NCI Gadi.

Users are free to adapt it for use on other platforms, for example by replacing the `nci-parallel` parallelisation method with Open-MPI, job arrays, or simple for-loops. 

If adapting this workflow to another compute environment, please refer to the earlier notes regarding issues executing the Wine DIA-NN installation from Lustre.

A future release will see the workflow written in Nextflow. This imminent release will be portable. 

Currently, it runs on SCIEX wiff files. We will test on other raw data types (TBA). 