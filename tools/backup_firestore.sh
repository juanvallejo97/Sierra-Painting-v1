#!/bin/bash
# Firestore Backup Script
# Exports all Firestore collections to Google Cloud Storage

set -e

# Configuration
PROJECT="${FIREBASE_PROJECT:-sierra-painting-staging}"
BACKUP_BUCKET="${BACKUP_BUCKET:-gs://sierra-painting-staging-backups}"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_PATH="${BACKUP_BUCKET}/${DATE}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Firestore backup...${NC}"
echo "Project: ${PROJECT}"
echo "Backup path: ${BACKUP_PATH}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with gcloud${NC}"
    echo "Run: gcloud auth login"
    exit 1
fi

# List collections to backup
echo -e "${YELLOW}Collections to backup:${NC}"
COLLECTIONS=(
    "users"
    "companies"
    "jobs"
    "time_entries"
    "customers"
    "estimates"
    "invoices"
    "auditLog"
)

for collection in "${COLLECTIONS[@]}"; do
    echo "  - ${collection}"
done
echo ""

# Start export
echo -e "${GREEN}Starting Firestore export...${NC}"
gcloud firestore export ${BACKUP_PATH} \
    --project=${PROJECT} \
    --collection-ids=$(IFS=,; echo "${COLLECTIONS[*]}") \
    --async

echo ""
echo -e "${GREEN}Backup initiated successfully!${NC}"
echo "Backup path: ${BACKUP_PATH}"
echo ""
echo "To check backup status:"
echo "  gcloud firestore operations list --project=${PROJECT}"
echo ""
echo "To list backups:"
echo "  gsutil ls ${BACKUP_BUCKET}/"
echo ""
echo "To restore:"
echo "  bash tools/restore_firestore.sh ${DATE}"

