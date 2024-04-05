## Input requirements

### Data
- wiff and wiff.scan inputs files
- proteome fasta 
- cohort-specific experimental library can be used for a library-based analysis, or user can run optional [step 1](./docs/detailed-user-guide.md#1-in-silico-library-generation-optional)

### DIA-NN resources
PC DIA-NN executable installed with Wine is required, and must be run with Wine from the local-to-node storage (will not work from Lustre filesystem). We have installed DIA-NN v 1.8.1 with [Wine 7.0.0](https://hub.docker.com/r/uvarc/wine) and copied the 'Clearcore' and 'Sciex' dll files (required for DIA-NN to read wiff input) into the DIA-NN install directory as per developer's guidelines. We have packaged this up into an archive named `dot_wine.tar`. Many thanks to [NCI](nci.org.au) for assistance with this. We have made this archive (1.8 GB) publicly available, and download details are provided under the [user guide](./detailed-user-guide.md#obtain-required-input-files).


The `dot_wine.tar` DIA-NN installation requires Wine with Mono to run. We have successfully used the [uvarc container](https://hub.docker.com/r/uvarc/wine) and the [Proteowizard container](https://hub.docker.com/r/chambm/pwiz-skyline-i-agree-to-the-vendor-licenses). The Proteowizard container requires [per-user set-up](./pwiz_image_setup.md) to run on Gadi.

For a library-free analysis, in-silico library generation should be performed with the [Linux version of DIA-NN](https://docker.ecosyste.ms/packages/biocontainers%2Fdiann/versions/v1.8.1_cv1) rather than the Wine-installed PC version. This is simply because the Linux version is much faster (3 minutes vs 45 minutes for a mammalian proteome).