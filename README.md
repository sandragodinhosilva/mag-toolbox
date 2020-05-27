# MAGG toolbox
Custom pipeline to analyse MAGs.

## 1. Get genome metrics
All the steps of this section require as **input**: 
- **folder with the MAGs in fasta format.**

### 1.1) Quality check - CheckM
CheckM: https://github.com/Ecogenomics/CheckM/wiki
Installation: https://github.com/Ecogenomics/CheckM/wiki/Installation
job submission:
```bash
# checkm lineage_wf -t ${NSLOTS:-1}  --tab_table -x fa -f $3 $1 $2 
qsub  -N checkm_job    /path_to/submission_script.sh /data/msb/user/MAG_folder /data/msb/user/output/checkm /data/msb/user/output/checkm.tsv
```
**Output** that will later be used on this workflow: checkm.tsv

### 1.2) Get taxonomy - Gtdbtk
gtdb_tk: https://github.com/Ecogenomics/GTDBTk
Installation: https://ecogenomics.github.io/GTDBTk/running/
job submission:
```bash
# gtdbtk  classify_wf --extension  fa  --cpus ${NSLOTS:-1} --genome_dir $1  --out_dir $2qsub  -N gtdbtk_job   /path_to/submission_script.sh /data/msb/user/MAG_folder /data/msb/user/output/
```
**Output** that will later be used: gtdbtk.bac120.summary.tsv 
**Note: **if adequate, also consider gtdbtk.ar122.markers_summary.tsv for the archaea domain.

### 1.3) Get genome metrics - BBtools
BBtools documentation: https://jgi.doe.gov/data-and-tools/bbtools/
Download: https://sourceforge.net/projects/bbmap/ 
Run the script **statswrapper.sh** on the folder with the MAGs
```bash
bash /data/msb/tools/bbtools/bbmap/statswrapper.sh *.fa > bbtools.txt
```
**Note:** Simply run the script **statswrapper.sh**  on the directory with the MAGs.
**Output** that will later be used: bbtools.txt
* * *
## 2) Merge data - Jupyter Notebook
All the steps necessary to merge the CheckM, gtdb_tk and BBtools output files are described in the following Jupyter Notebook with a Python Kernel: **Data_cleaning.ypnb**

It's necessary to have the tool Jupyter Notebooks or Jupyter Lab (recommended) to open this notebook. 
Link to installation guide:
https://jupyterlab.readthedocs.io/en/stable/getting_started/installation.html

**Note:** inside the notebook you will find the rules in use to classify MAGs in terms of quality (High/Medium).

**Output:** csv file with all the information: MAG_metrics.csv
* * *
## 3) Visualize overall dataset metrics
For a quick way of visualizing the dataset constructed so far, I recommend the use of the DataExplorer R package, created for Exploratory Data Analysis.

To run it on R:
```R
library(DataExplorer)
table <- read.csv("MAG_metrics.csv", header=TRUE, sep="\t")
create_report(table)
```
**Input: ** MAG_metrics.csv
**Output:** report.html (can be open in any browser).
* * *
## 4) Visualize taxonomy - MashTree + ITOL
### 4.1) MashTree
MashTree: https://github.com/lskatz/mashtree
**Input**: folder with the MAGs in fasta format.

**remote** - job submission:
```bash
qsub -N mashTree  /path_to/submission_script.sh /data/msb/user/MAG_folder/ /data/msb/user/mashtree.dnd
```
**Output** that will later be used: mashtree.dnd

### 4.1) ITOL
 https://itol.embl.de/
 **Input**: mashtree.dnd from MashTree.
 
 **Note: **you can use the data generated in the first step to add annotations to your ITOL tree (ex: taxonomy).

* * *
##5) Species differentiation
fastANI: https://github.com/ParBLiSS/FastANI

First, divide MAGs/bins into groups according to taxonomy **group_by_taxonomy.py**:
```bash
python group_by_taxonomy.py taxonomy.txt
```
This script also creates list to use as input in fastANI.

Run fastANI on every group:
```bash
conda activate FASTANI
for i in *.txt; do fastANI --rl $i --ql $i --fragLen 1000 -o $i-1000.txt$i; done/msb/silva/Liu
```
Group taxonomy files in same folder:
```bash
find . -name 'tax*' -exec mv "{}" ~/silva/Liu_et.al_2020/bins_organized4/Tax/ \;
```
aniSplitter: https://github.com/felipeborim789/aniSplitter
Run **aniSplitter.R**:
```bash
for i in {1..21}; do ./aniSplitter.R -d ~/silva/Liu_et.al_2020/bins_organized4/Out-1000/group$i -f ~/silva/Liu_et.al_2020/bins_organized4/Out-1000/group$i/group$i.$i.txt -t ~/silva/Liu_et.al_2020/bins_organized4/Out-1000/group$i/tax_group$i.txt -a 95; done
```

* * *
## 6) Genome annotation - Prokka
Prokka: https://github.com/tseemann/prokka
#### File division into subdirectories
**Input**: folder with the MAGs in fasta format.
To increase job speed on EVE cluster, the .fa files are divided in several folders, each containing 5 files. On the directory with all the bins, run: **folder_divider.sh**. Make sure that you are using Python3.

```bash
python folder_divider.sh
```

**To revert the process** (move all files from subdirectories to current directory)**:**
```bash
find ./*/* -type f -print0 | xargs -0 -I % mv % .
```

#### For loop submission on eve:
**Input**: folder containing all the folders created in the last step. Each folder contains 5 MAGs.
```bash
for i in *; do qsub -N $i /path_to/submission_script.sh 
 /data/msb/silva/MAG_folder/$i /data/msb/user/Prokka_ano/$i ; done
```

$1: folder with bins
$2: output folder
**Important notes: **
- submit paths to directories not to .fa files;
- if the output folder already has content, this will be overwritten by Prokka.
* * *
## 7) Miscelaneous
### 7.1) Extract rRNA sequences from MAGs
/data/msb/silva/barrnap_env)
Input: assembled MAGs - fasta
```bash
for i in *; do barrnap --kingdom bac --evalue 1e-02 --outseq ${i%.*}.fasta $i; done
find . -size 0 -delete #remove empty outputs
```
Note: the e-value of this example is really high. For better accuracy, lower the e-value (default: 1e-05)
If we only want results that include the 16S rRNA gene:
```bash
cp --parents `grep -lr '16S' ./*` ~/silva/Liu_et.al_2020/rRNA/16S/
```
### 7.2) Others
**In case you need to transform fastq files into fasta:**
```bash
for i in *.fastq; do seqtk seq -A $i >  ${i%.*}.fasta; done
