# Tosca - Proximity ligation data analysis

## Table of contents

1. [Introduction](#introduction)
2. [Pipeline summary](#pipeline-summary)
3. [Quick start (testing)](#quick-start-testing)
4. [Quick start (running)](#quick-start-running)
5. [Pipeline parameters](#pipeline-parameters)

## Introduction

Tosca is a Nextflow pipeline for the analysis of [hiCLIP]() or proximity ligation (e.g. [PARIS](), [SPLASH](), [COMRADES]()) sequencing data. It is containerised using Docker to ensure ease of installation. It is optimised for use on high-performance computing (HPC) clusters.

## Pipeline summary

1. Adapter and quality trimming ([`Cutadapt`](https://cutadapt.readthedocs.io))
2. Premapping to remove spliced reads ([`STAR`]())
3. Hybrid identification ([`pblat`](https://icebert.github.io/pblat/) and [`toscatools`]())
4. UMI-based deduplication ([`toscatools`]() and modified [`UMI-tools`](https://umi-tools.readthedocs.io/en/latest/))
5. Hybrid clustering ([`toscatools`]())
6. Annotation ([`toscatools`]())
7. Visualisation ([`toscatools`]())
    1. BAM
    2. BED
    3. Contact matrices
8. QC ([`MultiQC`]())

## Quick start (testing)

1. Ensure `Nextflow` and `Docker` or `Singularity` are installed on your system
2. Pull the main version of the pipeline from the GitHub repository:

```
nextflow pull amchakra/tosca -r main
```

3. Run the provided test dataset:

```
nextflow run amchakra/tosca -c test
```

4. Review the results

## Quick start (running)

1. Ensure `Nextflow` and `Docker` or `Singularity` are installed on your system
2. Pull the main version of the pipeline from the GitHub repository:

```
nextflow pull amchakra/tosca -r main
```

3. Download and unpack the pre-generated reference files:

```
wget -q reference.tar.gz
tar -xzvf reference.tar.gz
```

4. Prepare a `samplesheet.csv` with your sample names and paths to your FASTQ files, following the template:

```
sample,fastq
sample1,/path/to/file1.fastq.gz
sample2,/path/to/file2.fastq.gz
sample3,/path/to/file3.fastq.gz
```

5. Run the pipeline (the minimum parameters have been specified):

```
nextflow run amchakra/tosca -r main \
--input samplesheet.csv \
--genomedir /path/to/reference \
--org human
```

## Pipeline parameters

### General parameters

- `--input` specifies the input sample sheet
- `--outdir` specifies the output results directory
    - default: `./results`
- `--tracedir` specifies the pipeline run trace directory
    - default: `./results/pipeline_info`

### Genome parameters

Either `--genomedir`and `--org` or all of the other reference files need to be specified

- `--genomedir` specifies the genome reference directory
- `--org` specifies the organism (options are: `human`, `mouse`, `rat`)
- `--genome_fa` specifies the genome FASTA
- `--genome_fai` specifies the genome FASTA index
- `--star_genome` specifies the genome STAR index
- `--regions_gtf` specifies the genome gene/region/biotype annotation GTF (generated by [`iCount-Mini`](https://github.com/ulelab/iCount-Mini))
- `--transcript_fa` specifies the pseudo-transcriptome FASTA
- `--transcript_fai` specifies the pseudo-transcriptome FASTA index
- `--transcript_gtf` specifies the pseudo-transcriptome annotation GTF

### Alignment parameters

- `--split_size` specifies number of reads per FASTQ file when splitting for parallelised alignment
    - default: `100000`
- `--premap` specifies whether or not to performing premapping and filter spliced reads
    - default: `true`
- `--star_args` specifies optional additional STAR aligmnent parameters
- `--step_size` specifies pblat step size
    - default: `5`
- `--tile_size` specifies pblat tile size
    - default: `11`
- `--min_score` specifies pblat minimum score
    - default: `15`
- `--evalue` specifies pblat e-value threshold
    - default: `0.001`
- `--maxhits` specfies maximum number of pblat alignments per read
    - default: `100`

### Hybrid identification and characterisation

- `--dedup_method` specifies the UMI deduplication method (options are: `none`, `unique`, `percentile`, `cluster`, `adjacency`. `directional`)
    - default: `directional`
- `--umi_separator` specifies the UMI separator in the FASTQ read name
    - default: `_`
- `--percent_overlap` specifies the minimum percentage that one of the two hybrid arms need to overlap to be counted as overlapping
    - default: `0.75`
- `--sample_size` specifies the sample size to subsample hybrids reads per gene prior to clustering
    - default: `-1` i.e. no subsampling
- `--analyse_structure` specifies whether to analyse the duplex structure for each hybrid read
    - default: `false`
- `--shuffled_mfe` specifies whether to generate a control shuffled mean minimum free energy for each hybrid read
    - default: `false`
- `--clusters_only` specifies whether to analyse the structure for hybrid reads that are in a cluster
    - default: `true`
- `--atlas` specifies whether to generate an atlas of duplexes by combining hybrids from all the samples
    - default: `true`

### Visualisation

- `--goi` is a plain text file with one gene of interest per line to be visualised
- `--bin_size` specifies the size of each bin when generating the contact map matrices