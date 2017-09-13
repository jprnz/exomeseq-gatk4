#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: Whole Exome Sequencing
doc: |
  Whole Exome Sequence analysis using GATK best practices - Germline SNP & Indel Discovery
requirements:
  - class: ScatterFeatureRequirement
  - class: SubworkflowFeatureRequirement
inputs:
  # Intervals should come from capture kit (target intervals) bed format
  intervals: File[]?
  # Intervals should come from capture kit (bait intervals) bed format
  primary_intervals: File[]?
  interval_padding: int?
  # Read pairs, fastq format
  read_pairs:
      type: { type: array, items: { type: array, items: File }}
      format: http://edamontology.org/format_1930 # FASTQ format
  # reference genome, fasta
  reference_genome:
    type: File
    secondaryFiles:
    - .amb
    - .ann
    - .bwt
    - .pac
    - .sa
    - .fai
    - ^.dict
  # Number of threads to use
  threads: int?
  # Read Group annotation
  # Can be the project name
  library: string
  # e.g. Illumina
  platform: string
  field_order: string[]?
  # GATK
  GATKJar:
    type: File
  knownSites:
    type: File[] # vcf files of known sites, with indexing
    secondaryFiles:
    - .idx
  # Variant Recalibration - SNPs
  snp_resource_hapmap:
    type: File
    secondaryFiles:
    - .idx
  snp_resource_omni:
    type: File
    secondaryFiles:
    - .idx
  snp_resource_1kg:
    type: File
    secondaryFiles:
      - .idx
  # Variant Recalibration - Common
  resource_dbsnp:
    type: File
    secondaryFiles:
    - .idx
  # Variant Recalibration - Indels
  indel_resource_mills:
    type: File
    secondaryFiles:
    - .idx
outputs:
  fastqc_reports_dir:
    type: Directory
    outputSource: organize_directories/fastqc_reports_dir
  trim_reports_dir:
    type: Directory
    outputSource: organize_directories/trim_reports_dir
  raw_variants_dir:
    type: Directory
    outputSource: organize_directories/raw_variants_dir
  hs_metrics:
    type: { type: array, items: { type: array, items: File } }
    outputSource: preprocessing/hs_metrics
    doc: "VCF files from per sample variant calling"
  bams_markduplicates_dir:
    type: Directory
    outputSource: organize_directories/bams_markduplicates_dir
    doc: "BAM and bai files from markduplicates"
  bams_final_dir:
    type: Directory
    outputSource: organize_directories/bams_final_dir
    doc: "BAM files containing assembled haplotypes and locally realigned reads"
  joint_raw_variants:
    type: File
    outputSource: variant_discovery/joint_raw_variants
    doc: "GVCF file from joint genotyping calling"
  filtered_recalibrated_variants:
    type: File
    outputSource: variant_discovery/variant_recalibration_snps_indels_vcf
    doc: "The output filtered and recalibrated VCF file in which each variant is annotated with its VQSLOD value"
steps:
  preprocessing:
    run: exomeseq-01-preprocessing.cwl
    scatter: reads
    in:
      intervals: intervals
      primary_intervals: primary_intervals
      interval_padding: interval_padding
      reads: read_pairs
      reference_genome: reference_genome
      threads: threads
      library: library
      platform: platform
      field_order: field_order
      GATKJar: GATKJar
      knownSites: knownSites
      resource_dbsnp: resource_dbsnp
    out:
      - fastqc_reports
      - trim_reports
      - markduplicates_bam
      - recalibration_table
      - recalibrated_reads
      - raw_variants
      - haplotypes_bam
      - hs_metrics
  variant_discovery:
    run: exomeseq-02-variantdiscovery.cwl
    in:
      name: library
      intervals: intervals
      interval_padding: interval_padding
      raw_variants: preprocessing/raw_variants
      reference_genome: reference_genome
      threads: threads
      GATKJar: GATKJar
      snp_resource_hapmap: snp_resource_hapmap
      snp_resource_omni: snp_resource_omni
      snp_resource_1kg: snp_resource_1kg
      resource_dbsnp: resource_dbsnp
      indel_resource_mills: indel_resource_mills
    out:
      - joint_raw_variants
      - variant_recalibration_snps_tranches
      - variant_recalibration_snps_recal
      - variant_recalibration_snps_rscript
      - variant_recalibration_snps_vcf
      - variant_recalibration_snps_indels_tranches
      - variant_recalibration_snps_indels_recal
      - variant_recalibration_snps_indels_rscript
      - variant_recalibration_snps_indels_vcf
  organize_directories:
    run: exomeseq-03-organizedirectories.cwl
    in:
      fastqc_reports: preprocessing/fastqc_reports
      trim_reports: preprocessing/trim_reports
      bams_markduplicates: preprocessing/markduplicates_bam
      raw_variants: preprocessing/raw_variants
      bams_final: preprocessing/haplotypes_bam
    out:
      - fastqc_reports_dir
      - trim_reports_dir
      - bams_markduplicates_dir
      - raw_variants_dir
      - bams_final_dir
