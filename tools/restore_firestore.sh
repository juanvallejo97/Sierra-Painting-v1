#!/bin/bash
# Firestore Restore Script
# Imports Firestore backup from Google Cloud Storage

set -e

# Configuration
PROJECT="${FIREBASE_PROJECT:-sierra-painting-staging}"
BACKUP_BUCKET="${BACKUP_BUCKET:-gs://sierra-painting-staging-backups}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: Backup date/path required${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 <backup-date>       # e.g., 2025-10-12_14-30-00"
    echo "  $0 <full-gs-path>      # e.g., gs://bucket/2025-10-12_14-30-00"
    echo ""
    echo "Available backups:"
    gsutil ls ${BACKUP_BUCKET}/ | tail -5
    exit 1
fi

BACKUP_DATE=$1

# Determine full backup path
if [[ $BACKUP_DATE == gs://* ]]; then
    BACKUP_PATH=$BACKUP_DATE
else
    BACKUP_PATH="${BACKUP_BUCKET}/${BACKUP_DATE}"
fi

echo -e "${YELLOW}⚠️  WARNING: This will OVERWRITE current Firestore data!${NC}"
echo "Project: ${PROJECT}"
echo "Backup source: ${BACKUP_PATH}"
echo ""
read -p "Are you sure you want to restore? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Restore cancelled${NC}"
    exit 0
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if backup exists
if ! gsutil ls ${BACKUP_PATH}/ &> /dev/null; then
    echo -e "${RED}Error: Backup not found at ${BACKUP_PATH}${NC}"
    echo ""
    echo "Available backups:"
    gsutil ls ${BACKUP_BUCKET}/
    exit 1
fi

# Start restore
echo ""
echo -e "${GREEN}Starting Firestore import...${NC}"
gcloud firestore import ${BACKUP_PATH} \
    --project=${PROJECT} \
    --async

echo ""
echo -e "${GREEN}Restore initiated successfully!${NC}"
echo "Backup source: ${BACKUP_PATH}"
echo ""
echo "To check restore status:"
echo "  gcloud firestore operations list --project=${PROJECT}"
echo ""
echo "⚠️  Note: Restore can take 10-60 minutes depending on data size"
echo ""
echo "Verify restore:"
echo "  firebase firestore:get users --project=${PROJECT}"

