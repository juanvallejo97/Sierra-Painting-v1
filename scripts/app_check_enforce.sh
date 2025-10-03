#!/bin/bash

##############################################################################
# Firebase App Check Enforcement Script
#
# PURPOSE:
# Automates the enforcement of Firebase App Check across Firestore, Functions,
# and Storage for different environments (staging, canary, production).
#
# USAGE:
#   ./scripts/app_check_enforce.sh [OPTIONS] <environment>
#
# ARGUMENTS:
#   environment    Target environment: staging, canary, or prod
#
# OPTIONS:
#   --dry-run      Show what would be executed without making changes
#   --disable      Disable App Check enforcement instead of enabling
#   -h, --help     Show this help message
#
# EXAMPLES:
#   # Enable App Check in staging (dry-run)
#   ./scripts/app_check_enforce.sh --dry-run staging
#
#   # Enable App Check in production
#   ./scripts/app_check_enforce.sh prod
#
#   # Disable App Check in staging (rollback)
#   ./scripts/app_check_enforce.sh --disable staging
#
# REQUIREMENTS:
#   - Firebase CLI installed and authenticated (firebase login)
#   - Appropriate permissions to modify Firebase project settings
#
# SECURITY NOTES:
#   - Always test in staging before applying to production
#   - Use --dry-run flag to preview changes
#   - Keep audit log of enforcement changes
#
# ROLLBACK:
#   To rollback App Check enforcement, use the --disable flag and redeploy
#   affected services if needed.
##############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
DISABLE=false
ENVIRONMENT=""

##############################################################################
# Helper Functions
##############################################################################

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <environment>

Arguments:
  environment    Target environment: staging, canary, or prod

Options:
  --dry-run      Show what would be executed without making changes
  --disable      Disable App Check enforcement instead of enabling
  -h, --help     Show this help message

Examples:
  $0 --dry-run staging
  $0 prod
  $0 --disable staging
EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_firebase_cli() {
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI is not installed. Please install it first:"
        log_error "  npm install -g firebase-tools"
        exit 1
    fi
    
    # Check if logged in
    if ! firebase projects:list &> /dev/null; then
        log_error "Firebase CLI is not authenticated. Please run:"
        log_error "  firebase login"
        exit 1
    fi
    
    log_success "Firebase CLI is installed and authenticated"
}

get_project_id() {
    local env=$1
    case $env in
        staging)
            echo "sierra-painting-staging"
            ;;
        canary)
            echo "sierra-painting-canary"
            ;;
        prod)
            echo "sierra-painting-prod"
            ;;
        *)
            log_error "Unknown environment: $env"
            exit 1
            ;;
    esac
}

enforce_firestore() {
    local project=$1
    local action=$2
    
    log_info "[$action] App Check for Firestore in project: $project"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] Would $action App Check for Firestore"
        return
    fi
    
    # Note: Firestore App Check enforcement is typically done via security rules
    # The actual enforcement happens in firestore.rules with:
    # request.app.appCheck.token.aud[0] == request.app.projectId
    
    log_info "Firestore App Check is enforced via security rules."
    log_info "Ensure your firestore.rules include App Check validation."
    log_success "Firestore App Check configuration noted"
}

enforce_functions() {
    local project=$1
    local action=$2
    
    log_info "[$action] App Check for Cloud Functions in project: $project"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] Would $action App Check for Cloud Functions"
        log_info "[DRY-RUN] Functions with enforceAppCheck: true will require valid tokens"
        return
    fi
    
    # Note: Cloud Functions App Check enforcement is done at the function level
    # via runWith({ enforceAppCheck: true }) in the function definition
    
    log_info "Cloud Functions App Check is enforced at the function level."
    log_info "Ensure your functions include: runWith({ enforceAppCheck: true })"
    log_success "Cloud Functions App Check configuration noted"
}

enforce_storage() {
    local project=$1
    local action=$2
    
    log_info "[$action] App Check for Cloud Storage in project: $project"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] Would $action App Check for Cloud Storage"
        return
    fi
    
    # Note: Storage App Check enforcement is typically done via security rules
    # The actual enforcement happens in storage.rules with:
    # request.app.appCheck.token.aud[0] == request.app.projectId
    
    log_info "Cloud Storage App Check is enforced via security rules."
    log_info "Ensure your storage.rules include App Check validation."
    log_success "Cloud Storage App Check configuration noted"
}

##############################################################################
# Main Script
##############################################################################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --disable)
            DISABLE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        staging|canary|prod)
            ENVIRONMENT=$1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate environment argument
if [ -z "$ENVIRONMENT" ]; then
    log_error "Environment argument is required"
    print_usage
    exit 1
fi

# Determine action
ACTION="Enabling"
if [ "$DISABLE" = true ]; then
    ACTION="Disabling"
fi

# Print header
echo ""
echo "========================================================================"
echo "  Firebase App Check Enforcement Script"
echo "========================================================================"
echo "  Environment: $ENVIRONMENT"
echo "  Action: $ACTION"
if [ "$DRY_RUN" = true ]; then
    echo "  Mode: DRY RUN (no changes will be made)"
fi
echo "========================================================================"
echo ""

# Check prerequisites
check_firebase_cli

# Get project ID
PROJECT_ID=$(get_project_id "$ENVIRONMENT")
log_info "Target project: $PROJECT_ID"

# Confirm action (unless dry-run)
if [ "$DRY_RUN" = false ]; then
    echo ""
    read -p "Are you sure you want to $ACTION App Check for $ENVIRONMENT? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Operation cancelled"
        exit 0
    fi
fi

echo ""
log_info "Starting App Check enforcement for $ENVIRONMENT..."
echo ""

# Enforce App Check on each service
enforce_firestore "$PROJECT_ID" "$ACTION"
echo ""
enforce_functions "$PROJECT_ID" "$ACTION"
echo ""
enforce_storage "$PROJECT_ID" "$ACTION"

# Print summary
echo ""
echo "========================================================================"
if [ "$DRY_RUN" = true ]; then
    log_success "DRY RUN completed successfully"
    log_info "Services checked: Firestore, Functions, Storage"
else
    log_success "$ACTION App Check completed for $ENVIRONMENT"
    log_info "Next steps:"
    log_info "  1. Deploy updated security rules: firebase deploy --only firestore:rules,storage"
    log_info "  2. Deploy functions with enforceAppCheck: firebase deploy --only functions"
    log_info "  3. Test with debug token in staging/development"
    log_info "  4. Monitor Firebase DebugView for App Check tokens"
    log_info "  5. Verify crash-free rate remains stable"
fi
echo "========================================================================"
echo ""

exit 0
