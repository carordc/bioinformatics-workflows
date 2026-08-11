# QIIME 2 Amplicon Workflow

Reproducible workflow for processing paired-end amplicon sequencing data using **QIIME 2**, from raw FASTQ files to ASV abundance and taxonomic tables.

The workflow is designed as a general template and can be adapted for different amplicon markers and sequencing datasets.

## Workflow

```text
Paired-end FASTQ
        │
        ▼
      Import
        │
        ▼
Initial quality assessment
        │
        ▼
Primer removal — Cutadapt
        │
        ▼
Post-Cutadapt quality assessment
        │
        ▼
      DADA2
        │
        ├── Quality filtering
        ├── Denoising
        ├── Paired-end merging
        └── Chimera removal
        │
        ▼
      ASVs
        │
        ▼
Taxonomic classification
        │
        ▼
Taxonomic filtering
        │
        ▼
Final export
```

## Main script

### `01_qiime2_preprocessing.sh`

The script performs:

1. Import of paired-end FASTQ files using a manifest
2. Initial sequence quality assessment
3. Primer removal using Cutadapt
4. Quality assessment after primer removal
5. Denoising and ASV inference using DADA2
6. Evaluation of DADA2 denoising statistics
7. Feature-table and representative-sequence summaries
8. Extraction of the target amplicon region from the reference database
9. Training of a Naive Bayes taxonomic classifier
10. Taxonomic assignment
11. Optional taxonomic filtering
12. Export of final tables and representative sequences

## Required input

The workflow requires:

* Paired-end FASTQ files
* QIIME 2 manifest file
* Sample metadata
* Forward and reverse primer sequences
* Reference sequences for taxonomic classification
* Corresponding reference taxonomy

## Parameters

Dataset-specific parameters are defined at the beginning of the script.

Important parameters include:

```bash
FWD_PRIMER="FORWARD_PRIMER_SEQUENCE"
REV_PRIMER="REVERSE_PRIMER_SEQUENCE"

TRIM_LEFT_F=0
TRIM_LEFT_R=0

TRUNC_LEN_F=0
TRUNC_LEN_R=0

N_THREADS=24

SAMPLING_DEPTH=10000
```

**Do not use truncation lengths or sampling depths as universal values.**

Read quality should be inspected before defining DADA2 trimming/truncation parameters. Likewise, rarefaction depth should be selected according to the sequencing depth distribution of the processed samples.

## Primer removal

Primers are removed using **Cutadapt** before DADA2 processing.

Quality profiles are generated both before and after primer removal, allowing inspection of changes in read length and sequence quality.

## DADA2

DADA2 is used for:

* Quality filtering
* Error correction and denoising
* Amplicon sequence variant (ASV) inference
* Paired-end read merging
* Chimera removal

The denoising statistics should always be inspected to evaluate read retention throughout the pipeline.

## Taxonomic classification

Taxonomic classification is performed using a Naive Bayes classifier trained for the amplified region.

The reference database and primer sequences should therefore correspond to the marker analyzed.

Examples of possible reference databases include:

* SILVA — 16S/18S rRNA
* PR2 — 18S rRNA
* UNITE — ITS

Reference databases and classifier parameters should be selected according to the target marker and study design.

## Output

The workflow generates QIIME 2 artifacts (`.qza`), visualizations (`.qzv`) and exported files for downstream analyses.

Main exported outputs include:

```text
results/
│
├── table.qza
├── rep-seqs.qza
├── taxonomy.qza
├── denoising-stats.qza
│
└── export/
    ├── feature-table/
    ├── ASV-counts.tsv
    ├── taxonomy/
    └── representative-sequences/
```

These outputs can subsequently be imported into R or other statistical environments for ecological and statistical analyses.

## Notes

This workflow should be treated as a **template rather than a fixed protocol**.

Parameters related to read filtering, truncation, taxonomic reference databases and taxonomic filtering should be evaluated for each dataset.

Always inspect the intermediate quality-control outputs before proceeding with downstream analyses.
