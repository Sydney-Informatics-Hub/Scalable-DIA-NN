# Proteowizard container setup on Gadi 

Thanks to [Matt Chambers](https://github.com/chambm), this [Proteowizard](https://proteowizard.sourceforge.io/) container includes Wine and Mono, as required to run the PC version of DIA-NN on a Linux platform. It can also convert wiff to mzML, however since this repository contains a workflow to run on wiff input, instructions for that are not included here. 

Within this container, the `wine` folder is owned by 'root' and you cannot run singularity with `--fakeroot` on NCI Gadi. You will need to rebuild the container for your NCI Gadi user ID on a compute you have sudo access to (e.g. your desktop or laptop). Annoyingly, **this must be done uniquely for every user**. See [this stack overflow question](https://stackoverflow.com/questions/73328706/running-singularity-container-without-root-as-different-user-inside) for more details.

Run the following command on Gadi to obtain your `uid`:
```
id -u `whoami`
```

Your `username` is the user ID you log in to Gadi with. 

On the local machine you have sudo access to:

- [Install singularity](https://docs.sylabs.io/guides/3.0/user-guide/installation.html) (if not already installed)
- Create a new file called `pwiz.build`
- Within that file, add the following contents, replacing \<uid\> and \<username\> with your details:

```
Bootstrap: docker
From: chambm/pwiz-skyline-i-agree-to-the-vendor-licenses
%post

useradd -u <uid> <username>
chown -Rf --no-preserve-root <username> /wineprefix64
```
- Save `pwiz.build`, then run:

```
sudo singularity build pwiz.sif pwiz.build
```
- Transfer `pwiz.sif` to Gadi (e.g. with scp/rsync...)

This image can be used to run the PC version of DIA-NN that has been installed into a tar archive, available [here](./detailed-user-guide.md/#obtain-required-input-files). 