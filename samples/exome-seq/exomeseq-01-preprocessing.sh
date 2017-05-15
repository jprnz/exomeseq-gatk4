#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
ROOT_DIR=${SCRIPT_DIR}/../..
RUN_DATE=$(date +"%Y%m%d-%k%M%S")

WORKFLOWS_DIR=${ROOT_DIR}/workflows
DATA_DIR=${ROOT_DIR}/data
LOG_DIR=${ROOT_DIR}/log

SCRIPT_NAME=$(basename "$0")
SCRIPT_NAME_TRIMMED="${SCRIPT_NAME%.*}"
JOB_NAME="${SCRIPT_NAME_TRIMMED}-${RUN_DATE}"
echo $JOB_NAME

OUT_DIR=${DATA_DIR}/${JOB_NAME}/
LOG_DIR=${DATA_DIR}/${JOB_NAME}/

mkdir -p $OUT_DIR
mkdir -p $LOG_DIR
echo "Starting on $(date)..."
cwltool \
  --debug \
  --outdir ${OUT_DIR} \
  ${WORKFLOWS_DIR}/exomeseq-01-preprocessing.cwl \
  exomeseq-01-preprocessing.json \
  > >(tee ${LOG_DIR}/${SCRIPT_NAME_TRIMMED}-out.log) \
  2> >(tee ${LOG_DIR}/${SCRIPT_NAME_TRIMMED}-err.log >&2)
echo "Finished on $(date)..."
