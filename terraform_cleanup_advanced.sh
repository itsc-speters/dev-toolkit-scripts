#!/bin/bash

# Advanced Terraform Cleanup Script
# This script can preview or clean up Terraform temporary files and directories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=true
FORCE=false
BASE_DIR="$(pwd)"

# Function to show help
show_help() {
    cat << EOF
Terraform Cleanup Script

Usage: $0 [OPTIONS]

Options:
    -p, --preview    Show what would be deleted without actually deleting (default)
    -e, --execute    Actually perform the cleanup (opposite of preview)
    -f, --force      Skip confirmation prompt
    -d, --dir DIR    Specify base directory (default: current directory)
    -h, --help       Show this help message

Examples:
    $0                          # Preview what would be deleted (default)
    $0 --execute               # Actually perform cleanup
    $0 --preview               # Explicitly enable preview mode
    $0 --force --execute       # Cleanup without confirmation
    $0 --dir /path/to/repos    # Preview in specific directory
    $0 --execute --dir /path   # Cleanup in specific directory

This script removes:
    - .terraform/ directories
    - .terraform.lock.hcl files
    - terraform.tfstate files
    - terraform.tfstate.backup files
    - crash.log files
    - .terraform.tfstate.lock.info files
    - .terraform.d/ directories (plugin cache)
    - terraform.tfvars.backup files

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--preview)
            DRY_RUN=true
            shift
            ;;
        -e|--execute)
            DRY_RUN=false
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--dir)
            BASE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo -e "${RED}Error: Directory '$BASE_DIR' does not exist${NC}"
    exit 1
fi

# Convert to absolute path
BASE_DIR=$(cd "$BASE_DIR" && pwd)

echo -e "${BLUE}Terraform Cleanup Script${NC}"
echo -e "${BLUE}========================${NC}"
echo "Base directory: $BASE_DIR"
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}Mode: PREVIEW (no files will be deleted)${NC}"
else
    echo -e "${YELLOW}Mode: CLEANUP (files will be deleted)${NC}"
fi
echo ""

# Counter for items found/cleaned
total_items=0
projects_found=0

# Arrays to store found items
declare -a found_items
declare -a found_projects

# Function to add item to found list
add_found_item() {
    local item="$1"
    local project_dir="$2"
    found_items+=("$item")
    total_items=$((total_items + 1))
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${CYAN}[PREVIEW]${NC} Would remove: $item"
    else
        echo "  Removing: $item"
    fi
}

# Function to clean up terraform files in a directory
cleanup_terraform_files() {
    local dir="$1"
    local project_cleaned=false
    
    # Check if directory contains any .tf files (indicates it's a terraform project)
    if find "$dir" -maxdepth 1 -name "*.tf" -type f | grep -q .; then
        local project_name=$(basename "$dir")
        # Create relative path manually (compatible with macOS)
        local relative_path="${dir#$BASE_DIR/}"
        if [ "$relative_path" = "$dir" ]; then
            relative_path=$(basename "$dir")
        fi
        
        if [ "$project_cleaned" = false ]; then
            echo -e "${YELLOW}Terraform project: $relative_path${NC}"
            found_projects+=("$relative_path")
            projects_found=$((projects_found + 1))
            project_cleaned=true
        fi
        
        # Check for .terraform directory
        if [ -d "$dir/.terraform" ]; then
            add_found_item "$dir/.terraform" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -rf "$dir/.terraform"
            fi
        fi
        
        # Check for .terraform.d directory (plugin cache)
        if [ -d "$dir/.terraform.d" ]; then
            add_found_item "$dir/.terraform.d" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -rf "$dir/.terraform.d"
            fi
        fi
        
        # Check for .terraform.lock.hcl file
        if [ -f "$dir/.terraform.lock.hcl" ]; then
            add_found_item "$dir/.terraform.lock.hcl" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$dir/.terraform.lock.hcl"
            fi
        fi
        
        # Check for terraform.tfstate files
        if [ -f "$dir/terraform.tfstate" ]; then
            add_found_item "$dir/terraform.tfstate" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$dir/terraform.tfstate"
            fi
        fi
        
        # Check for terraform.tfstate.backup files
        if [ -f "$dir/terraform.tfstate.backup" ]; then
            add_found_item "$dir/terraform.tfstate.backup" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$dir/terraform.tfstate.backup"
            fi
        fi
        
        # Check for terraform.tfvars.backup files
        if [ -f "$dir/terraform.tfvars.backup" ]; then
            add_found_item "$dir/terraform.tfvars.backup" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$dir/terraform.tfvars.backup"
            fi
        fi
        
        # Check for crash.log files
        if [ -f "$dir/crash.log" ]; then
            add_found_item "$dir/crash.log" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$dir/crash.log"
            fi
        fi
        
        # Check for .terraform.tfstate.lock.info files
        if [ -f "$dir/.terraform.tfstate.lock.info" ]; then
            add_found_item "$dir/.terraform.tfstate.lock.info" "$dir"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$dir/.terraform.tfstate.lock.info"
            fi
        fi
        
        # Check for any .tfplan files
        for tfplan in "$dir"/*.tfplan; do
            if [ -f "$tfplan" ]; then
                add_found_item "$tfplan" "$dir"
                if [ "$DRY_RUN" = false ]; then
                    rm -f "$tfplan"
                fi
            fi
        done
        
        if [ "$project_cleaned" = true ]; then
            echo ""
        fi
    fi
}

# Function to recursively search and clean directories
search_and_clean() {
    local search_dir="$1"
    local depth="$2"
    
    # Prevent going too deep (safety measure)
    if [ $depth -gt 10 ]; then
        return
    fi
    
    # Process current directory
    cleanup_terraform_files "$search_dir"
    
    # Process subdirectories
    # Ensure search_dir doesn't end with slash for proper globbing
    local clean_search_dir="${search_dir%/}"
    for subdir in "$clean_search_dir"/*/; do
        if [ -d "$subdir" ]; then
            # Skip .git and other hidden directories, and common non-terraform directories
            basename_dir=$(basename "$subdir")
            if [[ ! "$basename_dir" =~ ^\. ]] && [[ "$basename_dir" != "node_modules" ]] && [[ "$basename_dir" != "vendor" ]]; then
                # Remove trailing slash to prevent double slashes in recursive calls
                clean_subdir="${subdir%/}"
                search_and_clean "$clean_subdir" $((depth + 1))
            fi
        fi
    done
}

# Main execution
if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    echo -e "${YELLOW}This script will remove Terraform temporary files and directories.${NC}"
    echo ""
    echo "Files/directories that will be removed:"
    echo "  - .terraform/ directories"
    echo "  - .terraform.d/ directories (plugin cache)"
    echo "  - .terraform.lock.hcl files"
    echo "  - terraform.tfstate files"
    echo "  - terraform.tfstate.backup files"
    echo "  - terraform.tfvars.backup files"
    echo "  - crash.log files"
    echo "  - .terraform.tfstate.lock.info files"
    echo "  - *.tfplan files"
    echo ""
    read -p "Do you want to proceed? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 0
    fi
    echo ""
fi

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}Starting preview...${NC}"
else
    echo -e "${BLUE}Starting cleanup...${NC}"
fi
echo ""

# Start the search and cleanup process
search_and_clean "$BASE_DIR" 0

echo -e "${BLUE}Operation completed!${NC}"
echo -e "${GREEN}Terraform projects found: $projects_found${NC}"
echo -e "${GREEN}Total items processed: $total_items${NC}"

if [ "$DRY_RUN" = true ]; then
    if [ $total_items -eq 0 ]; then
        echo "No Terraform temporary files found."
    else
        echo -e "${CYAN}Preview complete. Use --execute to actually delete these files.${NC}"
    fi
else
    if [ $total_items -eq 0 ]; then
        echo "No Terraform temporary files found to clean up."
    else
        echo "All Terraform temporary files have been successfully removed."
    fi
fi
