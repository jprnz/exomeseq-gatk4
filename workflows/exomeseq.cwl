#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
requirements:
  - class: ScatterFeatureRequirement
  - class: SubworkflowFeatureRequirement
inputs:
  # Intervals should come from capture kit
  intervals: string[]?
  # Read pairs, fastq format
  read_pairs:
      type: { type: array, items: { type: array, items: File } }
  # reference genome, fasta
  reference_genome: File
  # Number of threads to use
  threads: int?
  # Read Group annotation
  read_group_header: string
  # GATK
  GATKJar: File
  knownSites: File[] # vcf files of known sites, with indexing
  # Confidence threshold for calling a variant - 30
  stand_call_conf: double
  # Variant Recalibration - SNPs
  snp_resource_hapmap: File
  snp_resource_omni: File
  snp_resource_1kg: File
  # Variant Recalibration - Common
  resource_dbsnp: File
  # Variant Recalibration - Indels
  indel_resource_mills: File
outputs:
  qc_reports:
    type: { type: array, items: { type: array, items: File } }
    outputSource: preprocessing/qc_reports
  trim_reports:
    type: { type: array, items: { type: array, items: File } }
    outputSource: preprocessing/trim_reports
  # Recalibration
  recalibration_before:
    type: File[]
    outputSource: preprocessing/recalibration_before
  recalibration_after:
    type: File[]
    outputSource: preprocessing/recalibration_after
  recalibration_plots:
    type: File[]
    outputSource: preprocessing/recalibration_plots
  recalibrated_reads:
    type: File[]
    outputSource: preprocessing/recalibrated_reads
  per_sample_raw_variants:
    type: File[]
    outputSource: variant_discovery/per_sample_raw_variants
    doc: "VCF files from per sample variant calling"
  joint_raw_variants:
    type: File
    outputSource: variant_discovery/joint_raw_variants
    doc: "VCF file from joint genotyping calling"
  variant_recalibration_snps_tranches:
    type: File
    outputSource: variant_discovery/variant_recalibration_snps_tranches
    doc: "The output tranches file used by ApplyRecalibration in SNP mode"
  variant_recalibration_snps_recal:
    type: File
    outputSource: variant_discovery/variant_recalibration_snps_recal
    doc: "The output recal file used by ApplyRecalibration in SNP mode"
  variant_recalibration_snps_rscript:
    type: File
    outputSource: variant_discovery/variant_recalibration_snps_rscript
    doc: "The output rscript file generated by the VQSR in SNP mode to aid in visualization of the input data and learned model"
  variant_recalibration_indels_tranches:
    type: File
    outputSource: variant_discovery/variant_recalibration_indels_tranches
    doc: "The output tranches file used by ApplyRecalibration in INDEL mode"
  variant_recalibration_indels_recal:
    type: File
    outputSource: variant_discovery/variant_recalibration_indels_recal
    doc: "The output recal file used by ApplyRecalibration in INDEL mode"
  variant_recalibration_indels_rscript:
    type: File
    outputSource: variant_discovery/variant_recalibration_indels_rscript
    doc: "The output rscript file generated by the VQSR in INDEL mode to aid in visualization of the input data and learned model"
  variant_recalibration_snps_vcf:
    type: File
    outputSource: variant_discovery/variant_recalibration_snps_vcf
    doc: "The output filtered and recalibrated VCF file in SNP mode in which each variant is annotated with its VQSLOD value"
  variant_recalibration_indels_vcf:
    type: File
    outputSource: variant_discovery/variant_recalibration_indels_vcf
    doc: "The output filtered and recalibrated VCF file in INDEL mode in which each variant is annotated with its VQSLOD value"
steps:
  preprocessing:
    run: exomeseq-01-preprocessing.cwl
    scatter: reads
    in:
      intervals: intervals
      reads: read_pairs
      reference_genome: reference_genome
      threads: threads
      read_group_header: read_group_header
      GATKJar: GATKJar
      knownSites: knownSites
    out:
      - qc_reports
      - trim_reports
      - recalibration_before
      - recalibration_after
      - recalibration_plots
      - recalibrated_reads
  variant_discovery:
    run: exomeseq-02-variantdiscovery.cwl
    in:
      intervals: intervals
      mapped_reads: preprocessing/recalibrated_reads
      reference_genome: reference_genome
      threads: threads
      GATKJar: GATKJar
      stand_call_conf: stand_call_conf
      snp_resource_hapmap: snp_resource_hapmap
      snp_resource_omni: snp_resource_omni
      snp_resource_1kg: snp_resource_1kg
      resource_dbsnp: resource_dbsnp
      indel_resource_mills: indel_resource_mills
    out:
      - per_sample_raw_variants
      - joint_raw_variants
      - variant_recalibration_snps_tranches
      - variant_recalibration_snps_recal
      - variant_recalibration_snps_rscript
      - variant_recalibration_indels_tranches
      - variant_recalibration_indels_recal
      - variant_recalibration_indels_rscript
      - variant_recalibration_snps_vcf
      - variant_recalibration_indels_vcf
