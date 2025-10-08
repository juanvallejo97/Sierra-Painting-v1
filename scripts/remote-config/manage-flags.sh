#!/bin/bash

# Remote Config Flag Management Script
# Manage Firebase Remote Config feature flags

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo -e "${BLUE}Firebase Remote Config Flag Management${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  list                    List all feature flags"
  echo "  get <flag-name>         Get value of a specific flag"
  echo "  set <flag-name> <value> Set flag value (true/false)"
  echo "  enable <flag-name>      Enable a feature flag (set to true)"
  echo "  disable <flag-name>     Disable a feature flag (set to false)"
  echo "  export                  Export config to JSON file"
  echo "  import <file>           Import config from JSON file"
  echo ""
  echo "Options:"
  echo "  --project <project-id>  Firebase project ID (default: from .firebaserc)"
  echo "  --help                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 list"
  echo "  $0 get feature_b1_clock_in_enabled"
  echo "  $0 enable feature_b1_clock_in_enabled"
  echo "  $0 disable feature_new_scheduler_enabled"
  echo "  $0 export"
  echo "  $0 import config.json --project sierra-painting-staging"
  echo ""
}

# Check Firebase CLI
check_firebase_cli() {
  if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Error: Firebase CLI not found${NC}"
  echo "Install with: npm install -g firebase-tools@13.23.1"
    exit 1
  fi
}

# Get project ID
get_project_id() {
  if [ -n "$PROJECT" ]; then
    echo "$PROJECT"
  elif [ -f ".firebaserc" ]; then
    # Try to extract default project from .firebaserc
    grep -o '"default"[[:space:]]*:[[:space:]]*"[^"]*"' .firebaserc | cut -d'"' -f4
  else
    echo ""
  fi
}

# List all flags
list_flags() {
  local project=$(get_project_id)
  local project_arg=""
  
  if [ -n "$project" ]; then
    project_arg="--project $project"
  fi
  
  echo -e "${BLUE}📋 Remote Config Flags${NC}"
  echo "================================================"
  
  firebase remoteconfig:get $project_arg -o /tmp/firebase-config.json 2>/dev/null || {
    echo -e "${RED}❌ Error: Could not fetch Remote Config${NC}"
    echo "Make sure you're authenticated: firebase login"
    exit 1
  }
  
  # Parse and display flags (simplified - assumes standard structure)
  if [ -f "/tmp/firebase-config.json" ]; then
    echo -e "${GREEN}✓ Config fetched successfully${NC}"
    echo ""
    echo "Available flags:"
    # TODO: Parse JSON and display flags in a readable format
    cat /tmp/firebase-config.json | grep -o '"key"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | while read flag; do
      echo "  - $flag"
    done
    rm /tmp/firebase-config.json
  fi
}

# Get specific flag
get_flag() {
  local flag_name=$1
  local project=$(get_project_id)
  local project_arg=""
  
  if [ -n "$project" ]; then
    project_arg="--project $project"
  fi
  
  echo -e "${BLUE}🔍 Getting flag: $flag_name${NC}"
  
  firebase remoteconfig:get $project_arg -o /tmp/firebase-config.json 2>/dev/null || {
    echo -e "${RED}❌ Error: Could not fetch Remote Config${NC}"
    exit 1
  }
  
  # TODO: Parse JSON and extract specific flag value
  echo -e "${YELLOW}TODO: Implement JSON parsing for flag value${NC}"
  echo "Config file saved to /tmp/firebase-config.json"
  rm /tmp/firebase-config.json
}

# Enable flag (set to true)
enable_flag() {
  local flag_name=$1
  set_flag "$flag_name" "true"
}

# Disable flag (set to false)
disable_flag() {
  local flag_name=$1
  set_flag "$flag_name" "false"
}

# Set flag value
set_flag() {
  local flag_name=$1
  local value=$2
  local project=$(get_project_id)
  
  echo -e "${BLUE}⚙️  Setting flag: $flag_name = $value${NC}"
  
  echo -e "${YELLOW}TODO: Implement flag update${NC}"
  echo ""
  echo "Manual steps:"
  echo "  1. firebase remoteconfig:get --project $project -o config.json"
  echo "  2. Edit config.json and set $flag_name to $value"
  echo "  3. firebase remoteconfig:publish config.json --project $project"
  echo ""
  echo -e "${YELLOW}⚠️  Or use Firebase Console:${NC}"
  echo "  https://console.firebase.google.com/project/$project/config"
}

# Export config
export_config() {
  local project=$(get_project_id)
  local filename="remote-config-$(date +%Y%m%d-%H%M%S).json"
  
  echo -e "${BLUE}📦 Exporting Remote Config${NC}"
  
  firebase remoteconfig:get --project $project -o "$filename" 2>/dev/null || {
    echo -e "${RED}❌ Error: Could not export config${NC}"
    exit 1
  }
  
  echo -e "${GREEN}✓ Config exported to: $filename${NC}"
}

# Import config
import_config() {
  local filename=$1
  local project=$(get_project_id)
  
  if [ ! -f "$filename" ]; then
    echo -e "${RED}❌ Error: File not found: $filename${NC}"
    exit 1
  fi
  
  echo -e "${BLUE}📥 Importing Remote Config${NC}"
  echo -e "${YELLOW}⚠️  Warning: This will overwrite current config${NC}"
  read -p "Continue? (y/N): " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Import cancelled"
    exit 0
  fi
  
  firebase remoteconfig:publish "$filename" --project $project 2>/dev/null || {
    echo -e "${RED}❌ Error: Could not import config${NC}"
    exit 1
  }
  
  echo -e "${GREEN}✓ Config imported successfully${NC}"
}

# Main script
check_firebase_cli

# Parse arguments
COMMAND=${1:-help}
PROJECT=""

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

# Execute command
case $COMMAND in
  list)
    list_flags
    ;;
  get)
    if [ -z "$2" ]; then
      echo -e "${RED}❌ Error: Flag name required${NC}"
      usage
      exit 1
    fi
    get_flag "$2"
    ;;
  set)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo -e "${RED}❌ Error: Flag name and value required${NC}"
      usage
      exit 1
    fi
    set_flag "$2" "$3"
    ;;
  enable)
    if [ -z "$2" ]; then
      echo -e "${RED}❌ Error: Flag name required${NC}"
      usage
      exit 1
    fi
    enable_flag "$2"
    ;;
  disable)
    if [ -z "$2" ]; then
      echo -e "${RED}❌ Error: Flag name required${NC}"
      usage
      exit 1
    fi
    disable_flag "$2"
    ;;
  export)
    export_config
    ;;
  import)
    if [ -z "$2" ]; then
      echo -e "${RED}❌ Error: Filename required${NC}"
      usage
      exit 1
    fi
    import_config "$2"
    ;;
  help|--help)
    usage
    exit 0
    ;;
  *)
    echo -e "${RED}❌ Error: Unknown command: $COMMAND${NC}"
    echo ""
    usage
    exit 1
    ;;
esac
