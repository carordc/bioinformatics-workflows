#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# QIIME 2 AMPLICON PIPELINE
# ============================================================
#
# Description:
#   Standard paired-end amplicon workflow using QIIME 2.
#
# Steps:
#   1. Import demultiplexed FASTQ files
#   2. Inspect raw read quality
#   3. Remove primers with Cutadapt
#   4. Inspect post-primer-removal quality
#   5. Denoise with DADA2
#   6. Summarize denoising and feature table

#
# Important:
#   Parameters such as truncation lengths and sampling depth
#   MUST be chosen after inspecting the data.
#
# ============================================================


# ------------------------------------------------------------
# 1. USER-DEFINED PARAMETERS
# ------------------------------------------------------------

# QIIME 2 environment
QIIME_ENV="qiime2-2026.4"

# Input files
MANIFEST="manifest.tsv"
METADATA="metadata.tsv"

# Output directories
RESULTS_DIR="results"
EXPORT_DIR="${RESULTS_DIR}/export"

# Primer sequences
FWD_PRIMER="GTGCCAGCMGCCGCGGTAA"
REV_PRIMER="GGACTACHVGGGTWTCTAAT"

# DADA2 parameters
TRIM_LEFT_F=0
TRIM_LEFT_R=0

# Use 0 to avoid fixed-length truncation.
# Change only after inspecting quality profiles.
TRUNC_LEN_F=0
TRUNC_LEN_R=0

N_THREADS=24

# Taxonomic reference
REFERENCE_SEQS="silva-138-99-seqs.qza"
REFERENCE_TAXONOMY="silva-138-99-tax.qza"

# Classifier output
CLASSIFIER="${RESULTS_DIR}/classifier.qza"

# Optional target taxonomic group.
# For bacterial 16S datasets, for example: "Bacteria"
TARGET_TAXON="Bacteria"

# Rarefaction depth.
# Must be selected after inspecting feature-table summary.
SAMPLING_DEPTH=10000


# ------------------------------------------------------------
# 2. SETUP
# ------------------------------------------------------------

mkdir -p "${RESULTS_DIR}" "${EXPORT_DIR}"

echo "=========================================="
echo "QIIME 2 amplicon pipeline"
echo "=========================================="
echo "Manifest: ${MANIFEST}"
echo "Metadata: ${METADATA}"
echo "Threads: ${N_THREADS}"
echo "=========================================="


# ------------------------------------------------------------
# 3. IMPORT PAIRED-END SEQUENCES
# ------------------------------------------------------------

qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path "${MANIFEST}" \
  --output-path "${RESULTS_DIR}/paired-end-demux.qza" \
  --input-format PairedEndFastqManifestPhred33V2


# ------------------------------------------------------------
# 4. INITIAL QUALITY ASSESSMENT
# ------------------------------------------------------------

qiime demux summarize \
  --i-data "${RESULTS_DIR}/paired-end-demux.qza" \
  --o-visualization "${RESULTS_DIR}/demux-before-cutadapt.qzv"


# ------------------------------------------------------------
# 5. REMOVE PRIMERS WITH CUTADAPT
# ------------------------------------------------------------
#
# This step mirrors the explicit primer-removal step used in
# the DADA2/R workflow.
#

qiime cutadapt trim-paired \
  --i-demultiplexed-sequences "${RESULTS_DIR}/paired-end-demux.qza" \
  --p-front-f "${FWD_PRIMER}" \
  --p-front-r "${REV_PRIMER}" \
  --p-discard-untrimmed \
  --p-cores "${N_THREADS}" \
  --o-trimmed-sequences "${RESULTS_DIR}/paired-end-trimmed.qza" \
  --verbose


# ------------------------------------------------------------
# 6. POST-CUTADAPT QUALITY ASSESSMENT
# ------------------------------------------------------------

qiime demux summarize \
  --i-data "${RESULTS_DIR}/paired-end-trimmed.qza" \
  --o-visualization "${RESULTS_DIR}/demux-after-cutadapt.qzv"


# ------------------------------------------------------------
# 7. DADA2 DENOISING
# ------------------------------------------------------------
#
# Choose TRIM_LEFT and TRUNC_LEN values from the quality plots.
# DADA2 performs quality filtering, denoising, paired-end
# merging, and chimera removal.
#

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs "${RESULTS_DIR}/paired-end-trimmed.qza" \
  --p-trim-left-f "${TRIM_LEFT_F}" \
  --p-trim-left-r "${TRIM_LEFT_R}" \
  --p-trunc-len-f "${TRUNC_LEN_F}" \
  --p-trunc-len-r "${TRUNC_LEN_R}" \
  --p-n-threads "${N_THREADS}" \
  --o-table "${RESULTS_DIR}/table.qza" \
  --o-representative-sequences "${RESULTS_DIR}/rep-seqs.qza" \
  --o-denoising-stats "${RESULTS_DIR}/denoising-stats.qza"


# ------------------------------------------------------------
# 8. DADA2 DIAGNOSTICS
# ------------------------------------------------------------

qiime metadata tabulate \
  --m-input-file "${RESULTS_DIR}/denoising-stats.qza" \
  --o-visualization "${RESULTS_DIR}/denoising-stats.qzv"

qiime feature-table summarize \
  --i-table "${RESULTS_DIR}/table.qza" \
  --m-sample-metadata-file "${METADATA}" \
  --o-visualization "${RESULTS_DIR}/table.qzv"

qiime feature-table tabulate-seqs \
  --i-data "${RESULTS_DIR}/rep-seqs.qza" \
  --o-visualization "${RESULTS_DIR}/rep-seqs.qzv"


# ------------------------------------------------------------
# 9. EXTRACT AMPLICON REGION FROM REFERENCE
# ------------------------------------------------------------
#
# The classifier should ideally be trained for the same
# amplicon region amplified in the samples.
#

qiime feature-classifier extract-reads \
  --i-sequences "${REFERENCE_SEQS}" \
  --p-f-primer "${FWD_PRIMER}" \
  --p-r-primer "${REV_PRIMER}" \
  --p-trunc-len 0 \
  --p-min-length 0 \
  --p-max-length 0 \
  --o-reads "${RESULTS_DIR}/reference-amplicons.qza"


# ------------------------------------------------------------
# 10. TRAIN TAXONOMIC CLASSIFIER
# ------------------------------------------------------------

qiime feature-classifier fit-classifier-naive-bayes \
  --i-reference-reads "${RESULTS_DIR}/reference-amplicons.qza" \
  --i-reference-taxonomy "${REFERENCE_TAXONOMY}" \
  --o-classifier "${CLASSIFIER}"


# ------------------------------------------------------------
# 11. TAXONOMIC ASSIGNMENT
# ------------------------------------------------------------

qiime feature-classifier classify-sklearn \
  --i-classifier "${CLASSIFIER}" \
  --i-reads "${RESULTS_DIR}/rep-seqs.qza" \
  --p-n-jobs "${N_THREADS}" \
  --o-classification "${RESULTS_DIR}/taxonomy.qza"

qiime metadata tabulate \
  --m-input-file "${RESULTS_DIR}/taxonomy.qza" \
  --o-visualization "${RESULTS_DIR}/taxonomy.qzv"

qiime taxa barplot \
  --i-table "${RESULTS_DIR}/table.qza" \
  --i-taxonomy "${RESULTS_DIR}/taxonomy.qza" \
  --m-metadata-file "${METADATA}" \
  --o-visualization "${RESULTS_DIR}/taxa-bar-plots.qzv"


# ------------------------------------------------------------
# 12. OPTIONAL TAXONOMIC FILTER
# ------------------------------------------------------------
#
# Useful, for example, when retaining Bacteria in a 16S dataset.
# For 18S/ITS analyses, edit or skip this section as appropriate.
#

qiime taxa filter-table \
  --i-table "${RESULTS_DIR}/table.qza" \
  --i-taxonomy "${RESULTS_DIR}/taxonomy.qza" \
  --p-include "${TARGET_TAXON}" \
  --o-filtered-table "${RESULTS_DIR}/table-filtered.qza"

qiime feature-table summarize \
  --i-table "${RESULTS_DIR}/table-filtered.qza" \
  --m-sample-metadata-file "${METADATA}" \
  --o-visualization "${RESULTS_DIR}/table-filtered.qzv"


# ------------------------------------------------------------
# 13. EXPORT FINAL TABLES
# ------------------------------------------------------------

qiime tools export \
  --input-path "${RESULTS_DIR}/table-filtered.qza" \
  --output-path "${EXPORT_DIR}/feature-table"

biom convert \
  -i "${EXPORT_DIR}/feature-table/feature-table.biom" \
  -o "${EXPORT_DIR}/ASV-counts.tsv" \
  --to-tsv

qiime tools export \
  --input-path "${RESULTS_DIR}/taxonomy.qza" \
  --output-path "${EXPORT_DIR}/taxonomy"

qiime tools export \
  --input-path "${RESULTS_DIR}/rep-seqs.qza" \
  --output-path "${EXPORT_DIR}/representative-sequences"
