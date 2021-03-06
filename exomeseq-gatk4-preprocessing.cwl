#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
label: exomeseq-gatk4-preprocessing/v2.1.1
doc: Whole Exome Sequence preprocessing using GATK4 - v2.1.1
requirements:
  ScatterFeatureRequirement: {}
  SubworkflowFeatureRequirement: {}
  SchemaDefRequirement:
    types:
      - $import: types/FASTQReadPairType.yml
inputs:
  # Intervals should come from capture kit (target intervals) bed format
  target_intervals: File[]?
  # Intervals should come from capture kit (bait intervals) bed format
  bait_intervals: File[]?
  interval_padding: int?
  # Named read pair in FASTQ format
  read_pair:
    type: types/FASTQReadPairType.yml#FASTQReadPairType
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
  threads: int
  # Read Group annotation
  # Can be the project name
  library: string
  # e.g. Illumina
  platform: string
  known_sites:
    type: File[] # vcf files of known sites, with indexing
    secondaryFiles:
    - .idx
  resource_dbsnp:
    type: File
    secondaryFiles:
    - .idx
outputs:
  fastp_html_report:
    type: File
    outputSource: preprocessing/fastp_html_report
    doc: "QC/Trim report from fastp in HTML format"
  fastp_json_report:
    type: File
    outputSource: preprocessing/fastp_json_report
    doc: "QC/Trim report from fastp in JSON format"
  markduplicates_bam:
    type: File
    outputSource: preprocessing/markduplicates_bam
    doc: "BAM and bai files from markduplicates"
  markduplicates_metrics:
    type: File
    outputSource: preprocessing/markduplicates_metrics
    doc: "metrics file from markduplicates"
  recalibration_table:
    type: File
    outputSource: preprocessing/recalibration_table
    doc: "Table of recalibration"
  recalibrated_reads:
    type: File
    outputSource: preprocessing/recalibrated_reads
    doc: "BAM file containing recalibrated reads"
  haplotypes_bam:
    type: File
    outputSource: preprocessing/haplotypes_bam
    doc: "BAM file containing assembled haplotypes"
  raw_variants:
    type: File
    outputSource: preprocessing/raw_variants
    doc: "Variants from HaplotypeCaller"
steps:
  prepare_reference_data:
    run: subworkflows/exomeseq-gatk4-00-prepare-reference-data.cwl
    in:
      target_intervals: target_intervals
      bait_intervals: bait_intervals
      reference_genome: reference_genome
    out:
      - target_interval_list
      - bait_interval_list
  preprocessing:
    run: subworkflows/exomeseq-gatk4-01-preprocessing.cwl
    in:
      intervals: target_intervals
      interval_padding: interval_padding
      target_interval_list: prepare_reference_data/target_interval_list
      bait_interval_list: prepare_reference_data/bait_interval_list
      read_pair: read_pair
      reference_genome: reference_genome
      threads: threads
      library: library
      platform: platform
      known_sites: known_sites
      resource_dbsnp: resource_dbsnp
    out:
      - fastp_html_report
      - fastp_json_report
      - markduplicates_bam
      - markduplicates_metrics
      - recalibration_table
      - recalibrated_reads
      - raw_variants
      - haplotypes_bam
