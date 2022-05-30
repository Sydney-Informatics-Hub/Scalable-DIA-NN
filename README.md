# DiaNN
AWS/Ronin big machine (windows) and multinode (linux) instructions to run https://github.com/vdemichev/DiaNN

# Set up on Ronin Windows
* Make a machine. You probably want the flavours starting with C (compute), R (memory), or M (also good). You want to use the biggest number (i.e. the most recent generation of flavours, at least 5, maybe 6 or 7). You probably only want to use flavours with no other letters following the number, execpt A (AMD instead of the default Intel) - these are cheaper and possibly faster. So to start with pick "C5.LARGE" - we will change this to "C5.24XLARGE" once we have everything set up and are ready to spend the big bucks.
* Change password (because of a weird windows bug, where setting the initial password does nothing).
* Connect to Machine with RDP.
* Allow downloads: https://sydneyuni.atlassian.net/wiki/spaces/RC/pages/1171423886/Tips+and+tricks+and+hacks
* Download Firefox (or similar)
* Download WinSCP (or similar)
* Mount external drive: https://blog.ronin.cloud/make-storage-available-windows/
* Copy data over using RDS ftp connection at research-data.ext.sydney.edu.au
BUT! research-data-ext is unfortunately very flakey, so we may have to "push" data to the server rather than "pull" data from the RDS, to do that:
* Allow sftp to windows: https://winscp.net/eng/docs/guide_windows_openssh_server#installing_sftp_ssh_server
* Copy data over e.g.:
```
ssh hpc.sydney.edu.au
cd /rds/PRJ-NASHplasma/WD_EXP1/Expanded Wiff/
sftp Administrator@<yourmachinename>.SYDNEYUNI.CLOUD
cd /D:/
mkdir Expanded_Wiff
put *
```
Another even better way is to mount a drive on a linux machine, then just rsync so you don't have to use sftp between linux and windows. Then detach and go!
Once the data is on the drive and within the Ronin ecosystem and off RDS (approx 10 hours per TB), you may snapshot it, detach it, re-attach it to other instances, etc!
Now:
* Donwload Diann: https://github.com/vdemichev/DiaNN#installation
* Download Protowizard: https://proteowizard.sourceforge.io/download.html
* Install Diann:
*For .wiff support, download and install ProteoWizard - choose the version (64-bit) that supports "vendor files"). Then copy all files with 'Clearcore' or 'Sciex' in their name (these will be .dll files) from the ProteoWizard folder to the DIA-NN installation folder (the one which contains diann.exe, DIA-NN.exe and a bunch of other files).*
* Run DIANN! Or before this point, you may want to shut off the machine and renofigure the instance type, then run it!

Done!

# Set up on Ronin Linux Auto-Scale Cluster

Make the machine and connect to it. Choose a flavour (probably C5 or M5 series are probably good with enough RAM and CPU).

Setup singularity
```
spack install singularity
sudo su
bash /apps/spack/opt/spack/linux-ubuntu18.04-skylake_avx512/gcc-7.5.0/singularity-3.8.5-uy6ax3f5654sn76me3ykamfi2x5l2m3t/bin/spack_perms_fix.sh
```

Pull the ```diann``` and ```msconvert``` images:
```
spack load singularity
cd /apps
singularity pull docker://biocontainers/diann:v1.8.1_cv1
singularity pull docker://chambm/pwiz-skyline-i-agree-to-the-vendor-licenses
```

Install gnu-parallel into /apps
```
wget https://ftpmirror.gnu.org/parallel/parallel-latest.tar.bz2
tar -xvjf parallel-latest.tar.bz2
cd parallel
./configure --prefix /apps
make
make install
```

Mount an additional exfat drive to the cluster
```
sudo apt update -y
sudo apt-get -y install exfat-fuse exfat-utils
sudo mkdir /mnt/data
lsblk #To find where the partition is located, in my case nve3n1p2
sudo mount  -t exfat /dev/nvme3n1p2 /mnt/data
```

Setup the Mass Spec files for reading and the output folders and copy data to the cluster, e.g.
```
mkdir /shared/WD_EXP1
mkdir /shared/out

scp -i ~/.ssh/dkey.pem sp_human_160321.fasta ubuntu@dianncluster.sydneyuni.cloud:/shared/sp_human_160321.fasta
scp -i ~/.ssh/dkey.pem  *.wiff ubuntu@dianncluster.sydneyuni.cloud:/shared/WD_EXP1/
```

You should also checksum the data to make sure nothing was lost in the transfer. e.g.
```
md5sum WD_EXP1/Expanded\ WIFF/* > md5sums.txt
scp -i ~/.ssh/dkey.pem   md5sums.txt ubuntu@dianncluster.sydneyuni.cloud:/shared/WD_EXP1/
md5sum -c md5sums.txt
```


## Convert .wiff to .mzML as required on Linux DiaNN

The ```msconvert``` utility is required to make files that are readable on Linux [https://github.com/vdemichev/DiaNN#raw-data-formats](https://github.com/vdemichev/DiaNN#raw-data-formats)

Make a slurm script to convert .wiff to .mzML, ```run_msconvert.sh```
```
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=96

spack load singularity

cd /shared/DATA/
ls -d /shared/DATA/*.wiff | /apps/bin/parallel --jobs 0 \
        /usr/bin/time -v singularity run --fakeroot --env WINEDEBUG=-all -B /shared/:/shared/ \
        /apps/pwiz-skyline-i-agree-to-the-vendor-licenses_latest.sif \
        wine msconvert {} --32 --filter "peakPicking vendor msLevel=1-" -o /shared/WD_EXP1/  --outfile {.}.mzML
```

Execute with 
```
sbatch run_msconvert.sh
```

Or, because I had the data on a mounted drive not easily visible by the compute nodes, I just ran it on the head node like so. Firstly, make a file with all the gnu parallel commands:
```
cd /mnt/data/Expanded_WIFF

for i in `ls -d *.wiff`; 
        do echo '/usr/bin/time -v singularity run --fakeroot --env WINEDEBUG=-all -B /shared/:/shared/ -B /apps:/apps -B/mnt/data:/mnt/data \
        /apps/pwiz-skyline-i-agree-to-the-vendor-licenses_latest.sif wine msconvert \
        '"$PWD"/${i}' --32 --filter "peakPicking vendor msLevel=1-" -o /shared/WD_EXP1/ --outfile '${i%%.*}'.mzML'; 
        done > /shared/commands.txt
```
And run them in a tmux session:
```
cd /shared/
tmux
parallel < commands.txt
cntrl+b d
```
Keep in mind this uses around 4GB of storage per process in a tmp file (defaulted to the root drive /tmp/root-fs). Be wary not to fill your drive. This takes around 1 hour per file per cpu.

You can get a list of the currently running sessions using `tmux list-sessions` or simply `tmux ls`, now attach to a running session with command `tmux attach-session -t <session-name>`.




## Run diann

Create a config file with *most* of the DiaNN options, call it ```diann.cfg``` or whatever.

>```--lib --threads 96 --verbose 1  --qvalue 0.01 --matrices --gen-spec-lib --predictor --prosit --fasta-search --min-fr-mz 150 --max-fr-mz 1500 --met-excision --cut K*,R* --missed-cleavages 1 --min-pep-len 7 --max-pep-len 30 --min-pr-mz 400 --max-pr-mz 900 --min-pr-charge 1 --max-pr-charge 4 --unimod4 --var-mods 1 --var-mod UniMod:1,42.010565,*n --monitor-mod UniMod:1 --double-search --reanalyse --smart-profiling --peak-center```

We want to batch the work into reasonable chunks, some discussion or thought could go further into this, but my approach was to simply split into 4 batches of about 80 files each based on experiment index. A better way may be to randomly subset into however many nodes you want to run on. Nevertheless, we must list these data in a file which we will pass to `diann` to read:
```
for i in 061221_WD_EXP1_1_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_1.txt
for i in 061221_WD_EXP1_2_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_2.txt
for i in 061221_WD_EXP1_3_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_3.txt
for i in 061221_WD_EXP1_4_*.wiff; do echo "--f /shared/WD_EXP1/"${i%%.*}".mzML \\"; done > /apps/scripts/dinput_4.txt
```

Make a slurm script to run diann, ```run_diann.sh```

```
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=96
#Assume there are 96 CPUS availble per node. Adjust as needed

spack load singularity

/usr/bin/time -v singularity run --bind /shared:/shared --bind /apps:/apps /apps/diann_v1.8.1_cv1.sif /bin/bash -c \
        "diann `cat /apps/scripts/dconfig.txt` \
        --fasta /shared/sp_human_160321.fasta \
        `cat /apps/scripts/dinput_${SLURM_ARRAY_TASK_ID}.txt` \
        --out /shared/out/Library_Free_Search_SP_HUMAN_061221_WD_EXP1_${SLURM_ARRAY_TASK_ID}.tsv \
        --out-lib /shared/out/Library_Free_Search_SP_HUMAN_LIB_061221_WD_EXP1_${SLURM_ARRAY_TASK_ID}.tsv"
```

Execute with:
```
sbatch -a [1-4] run_diann.sh
```

## Combine the output files from each of the batches

```
head -1 Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_1.tsv > results.tsv
head -1 Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_1.stats.tsv > results.stats.tsv

for i in Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_?.stats.tsv; do tail -n +2 $i >> results.stats.tsv; done
for i in Library_Free_Search_SP_HUMAN_061221_WD_EXP1_1_?.tsv; do tail -n +2 $i >> results.tsv; done
```

Generate a report (not sure if this tool is avaible on Linux, but in Windows e.g:
```
C:\DIA-NN\1.8.1> dia-nn-plotter.exe C:\WORK\Projects\diann\results.stats.tsv C:\WORK\Projects\diann\results.tsv C:\WORK\Projects\diann\res.pdf
```
