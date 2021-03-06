#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
requirements:
  SchemaDefRequirement:
    types:
      - $import: ../types/ExomeseqStudyType.yml
  MultipleInputFeatureRequirement: {}
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}
inputs:
  study_type:
    type: ../types/ExomeseqStudyType.yml#ExomeseqStudyType
  name: string
  intervals: File[]?
  interval_padding: int?
  # target intervals in picard interval_list format (created from intervals bed file)
  target_interval_list: File
  raw_variants: File[]
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
  joint_raw_variants:
    type: File
    outputSource: joint_genotyping/output_vcf
    doc: "VCF file from joint genotyping calling"
  variant_recalibration_snps_tranches:
    type: File
    outputSource: variant_recalibration_snps/output_tranches
    doc: "The output tranches file used by ApplyVQSR in SNP mode"
  variant_recalibration_snps_recalibration:
    type: File
    outputSource: variant_recalibration_snps/output_recalibration
    doc: "The output recalibration file used by ApplyVQSR in SNP mode"
  variant_recalibration_combined_vcf:
    type: File
    outputSource: apply_vqsr_snps/output_recalibrated_variants
    doc: "The output VCF file after INDEL and SNP recalibration"
  variant_recalibration_indels_tranches:
    type: File
    outputSource: variant_recalibration_indels/output_tranches
    doc: "The output tranches file used by ApplyVQSR in INDEL mode"
  variant_recalibration_snps_indels_recalibration:
    type: File
    outputSource: variant_recalibration_indels/output_recalibration
    doc: "The output recalibration file used by ApplyVQSR in INDEL mode"
  variant_recalibration_indels_vcf:
    type: File
    outputSource: apply_vqsr_indels/output_recalibrated_variants
    doc: "The output VCF file after INDEL recalibration"
  detail_metrics:
    type: File
    outputSource: collect_metrics/output_detail_metrics
  summary_metrics:
    type: File
    outputSource: collect_metrics/output_summary_metrics
steps:
  generate_joint_filenames:
    run: ../utils/generate-joint-filenames-gatk4.cwl
    in:
      name: name
    out:
      - raw_variants_filename
      - snps_recalibration_filename
      - snps_tranches_filename
      - snps_recalibrated_variants_filename
      - indels_recalibration_filename
      - indels_tranches_filename
      - indels_recalibrated_variants_filename
      - combined_recalibrated_variants_filename
  combine_variants:
    run: ../tools/GATK4/GATK4-CombineGVCFs.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 2
        ramMin: 16384
    in:
      reference: reference_genome
      output_vcf_filename: generate_joint_filenames/raw_variants_filename
      variants: raw_variants
    out:
      - output_vcf
  joint_genotyping:
    run: ../tools/GATK4/GATK4-GenotypeGVCFs.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 2
        ramMin: 10240
    in:
      reference: reference_genome
      output_vcf_filename: generate_joint_filenames/raw_variants_filename
      dbsnp: resource_dbsnp
      annotation_groups: { default: ['StandardAnnotation','AS_StandardAnnotation'] }
      only_output_calls_starting_in_intervals: { default: true }
      use_new_qual_calculator: { default: true }
      variants: combine_variants/output_vcf
      intervals: intervals
      interval_padding: interval_padding
      java_opt: { default: "-Xmx5g -Xms5g" }
    out:
      - output_vcf
  generate_annotations_indels:
    run: ../utils/generate-variant-recalibration-annotation-set.cwl
    in:
      study_type: study_type
      base_annotations:
        default: ["FS", "ReadPosRankSum", "MQRankSum", "QD", "SOR"]
    out:
      - annotations
  generate_annotations_snps:
    run: ../utils/generate-variant-recalibration-annotation-set.cwl
    in:
      study_type: study_type
      base_annotations:
        default: ["QD", "MQRankSum", "ReadPosRankSum", "FS", "MQ", "SOR"]
    out:
      - annotations
  variant_recalibration_indels:
    run: ../tools/GATK4/GATK4-VariantRecalibrator-Indels.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 2
        ramMin: 49152
    in:
      java_opt: { default: "-Xmx24g -Xms24g" }
      variants: joint_genotyping/output_vcf
      output_recalibration_filename: generate_joint_filenames/indels_recalibration_filename
      output_tranches_filename: generate_joint_filenames/indels_tranches_filename
      tranches: { default: ["100.0", "99.95", "99.9", "99.8", "99.6", "99.5", "99.4", "99.3", "99.0", "98.0", "97.0", "90.0"] }
      annotations: generate_annotations_indels/annotations
      mode: { default: "INDEL" }
      max_gaussians: { default: 4}
      resource_mills: indel_resource_mills
      resource_dbsnp: resource_dbsnp
    out:
      - output_recalibration
      - output_tranches
  variant_recalibration_snps:
    run: ../tools/GATK4/GATK4-VariantRecalibrator-SNPs.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 2
        ramMin: 6144
    in:
      java_opt: { default: "-Xmx3g -Xms3g" }
      variants: joint_genotyping/output_vcf
      output_recalibration_filename: generate_joint_filenames/snps_recalibration_filename
      output_tranches_filename: generate_joint_filenames/snps_tranches_filename
      tranches: { default: ["100.0", "99.95", "99.9", "99.8", "99.6", "99.5", "99.4", "99.3", "99.0", "98.0", "97.0", "90.0"] }
      annotations: generate_annotations_snps/annotations
      mode: { default: "SNP" }
      max_gaussians: { default: 6}
      resource_hapmap: snp_resource_hapmap
      resource_omni: snp_resource_omni
      resource_1kg: snp_resource_1kg
      resource_dbsnp: resource_dbsnp
    out:
      - output_recalibration
      - output_tranches
  apply_vqsr_indels:
    run: ../tools/GATK4/GATK4-ApplyVQSR.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 1
        ramMin: 10240
    in:
      java_opt: { default: "-Xmx5g -Xms5g" }
      output_recalibrated_variants_filename: generate_joint_filenames/indels_recalibrated_variants_filename
      variants: joint_genotyping/output_vcf
      recalibration_file: variant_recalibration_indels/output_recalibration
      tranches_file: variant_recalibration_indels/output_tranches
      truth_sensitivity_filter_level: { default: 99.7 }
      create_output_variant_index: { default: true }
      mode: { default: "INDEL" }
    out:
      - output_recalibrated_variants
  apply_vqsr_snps:
    run: ../tools/GATK4/GATK4-ApplyVQSR.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 1
        ramMin: 10240
    in:
      java_opt: { default: "-Xmx5g -Xms5g" }
      output_recalibrated_variants_filename: generate_joint_filenames/combined_recalibrated_variants_filename
      variants: apply_vqsr_indels/output_recalibrated_variants
      recalibration_file: variant_recalibration_snps/output_recalibration
      tranches_file: variant_recalibration_snps/output_tranches
      truth_sensitivity_filter_level: { default: 99.7 }
      create_output_variant_index: { default: true }
      mode: { default: "SNP" }
    out:
      - output_recalibrated_variants
  extract_sequence_dict:
    run: ../utils/extract-secondary-file.cwl
    in:
      file: reference_genome
      pattern: { default: '.dict'}
    out:
      - extracted
  collect_metrics:
    run: ../tools/GATK4/GATK4-CollectVariantCallingMetrics.cwl
    requirements:
      - class: ResourceRequirement
        coresMin: 2
        ramMin: 12288
    in:
      java_opt: { default: "-Xmx6g -Xms6g" }
      input_vcf: apply_vqsr_snps/output_recalibrated_variants
      dbsnp: resource_dbsnp
      sequence_dictionary: extract_sequence_dict/extracted
      output_metrics_filename_prefix: name
      thread_count: { default: 8 }
      target_intervals: target_interval_list
    out:
      - output_detail_metrics
      - output_summary_metrics
