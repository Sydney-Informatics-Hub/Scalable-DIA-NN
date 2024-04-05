## Test dataset

A test dataset containing four samples generated on SCIEX ZenoTOF is available. To obtain the test data:

```
wget https://sihbiopublic.blob.core.windows.net/scalable-diann/test_dataset.tar.gz
wget https://sihbiopublic.blob.core.windows.net/scalable-diann/test_dataset.tar.gz.md5
md5sum -c test_dataset.tar.gz.md5
tar -zxvf test_dataset.tar.gz
```
This will unpack `mouse_proteome.fasta` and a directory `zenotof_wiff` containing the raw data. To run the full workflow using these inputs, the path to these files can then be supplied in the parameters setup file under `fasta` and `wiff_dir` parameters respectively, as per instructions in the [user guide](./detailed-user-guide.md/#0-parameter-setup).