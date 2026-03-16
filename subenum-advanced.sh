#!/bin/bash

# ==============================================================================
# Advanced Recursive Subdomain Enum & Scope Enforcer
# Designed for n8n Automation (Kali Linux)
# Tools used: subfinder, assetfinder, scilla
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if domain is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No domain provided${NC}"
    echo "Usage: $0 <domain.com> [out_of_scope.txt]"
    exit 1
fi

DOMAIN=$1
OUT_OF_SCOPE_FILE=$2
mkdir -p "$DOMAIN/recon"
ALL_SUBDOMAINS="$DOMAIN/recon/all_subdomains_${DOMAIN}.txt"
FINAL_SUBDOMAINS="$DOMAIN/recon/final_subdomains_${DOMAIN}.txt"

print_status() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $1"; }
print_result() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# ------------------------------------------------------------------------------
# Function: Enumerate a specific domain
# ------------------------------------------------------------------------------
enumerate_domain() {
    local target_domain=$1
    local output_file=$2
    local level=$3
    
    print_status "Enumerating ${PURPLE}level $level${NC} for: $target_domain"
    
    {
        # Subfinder
        if command -v subfinder &> /dev/null; then
            subfinder -d "$target_domain" -silent -all 2>/dev/null
        fi
        
        # Assetfinder
        if command -v assetfinder &> /dev/null; then
            assetfinder --subs-only "$target_domain" 2>/dev/null
        fi
        
        # Scilla
        if command -v scilla &> /dev/null; then
            scilla subdomain -target "$target_domain" 2>/dev/null | grep -E "^[a-zA-Z0-9.-]+\\.$target_domain$" 2>/dev/null
        fi
    } | sort -u >> "$output_file"
}

# Clean workspace
rm -f "$ALL_SUBDOMAINS" "$FINAL_SUBDOMAINS" "$DOMAIN/recon"/temp_*.txt

# ------------------------------------------------------------------------------
# Layer 1: Initial Discovery
# ------------------------------------------------------------------------------
print_status "Starting Layer 1 subdomain enumeration for: ${BLUE}$DOMAIN${NC}"
enumerate_domain "$DOMAIN" "$ALL_SUBDOMAINS" "1"

# ------------------------------------------------------------------------------
# Layer 2 & 3: Deep Recursion
# ------------------------------------------------------------------------------
FIRST_LEVEL_SUBS=$(cat "$ALL_SUBDOMAINS" 2>/dev/null | sort -u)
print_result "Found $(echo "$FIRST_LEVEL_SUBS" | wc -l) Layer 1 subdomains."

recursive_enum() {
    local subdomain=$1
    local all_subs_file=$2
    local current_depth=$(echo "$subdomain" | tr -cd '.' | wc -c)
    local root_depth=$(echo "$DOMAIN" | tr -cd '.' | wc -c)
    
    # We want to recurse 2-3 levels deeper than the root domain
    if [[ "$subdomain" == "$DOMAIN" ]] || [[ $((current_depth - root_depth)) -ge 3 ]]; then
        return
    fi
    
    # Create temp file for this subdomain
    local temp_file="$DOMAIN/recon/temp_${RANDOM}.txt"
    enumerate_domain "$subdomain" "$temp_file" "$((current_depth - root_depth + 1))" &
}

print_status "Starting parallel deep recursive enumeration (up to 4 layers)..."
for sub in $FIRST_LEVEL_SUBS; do
    recursive_enum "$sub" "$ALL_SUBDOMAINS"
    
    # Limit parallel processes to avoid system crash / ban
    if [ $(jobs -r | wc -l) -ge 15 ]; then
        wait -n
    fi
done

print_status "Waiting for remaining recursive jobs to complete..."
wait

# Combine and Deduplicate
print_status "Combining results..."
find "$DOMAIN/recon" -name "temp_*.txt" -type f -exec cat {} \; >> "$ALL_SUBDOMAINS" 2>/dev/null
rm -f "$DOMAIN/recon"/temp_*.txt

print_status "Deduplicating all results..."
cat "$ALL_SUBDOMAINS" 2>/dev/null | sort -u > "$FINAL_SUBDOMAINS"
TOTAL_COUNT=$(cat "$FINAL_SUBDOMAINS" 2>/dev/null | wc -l)
print_result "Total Unique Subdomains (Pre-Filter): ${BLUE}$TOTAL_COUNT${NC}"

# ------------------------------------------------------------------------------
# Out-of-Scope Filtering
# ------------------------------------------------------------------------------
if [ -n "$OUT_OF_SCOPE_FILE" ] && [ -f "$OUT_OF_SCOPE_FILE" ]; then
    print_status "Applying Out-Of-Scope Regex Filter from: ${YELLOW}$OUT_OF_SCOPE_FILE${NC}"
    grep -v -f "$OUT_OF_SCOPE_FILE" "$FINAL_SUBDOMAINS" > "$DOMAIN/recon/filtered_subs.txt"
    mv "$DOMAIN/recon/filtered_subs.txt" "$FINAL_SUBDOMAINS"
    FINAL_COUNT=$(cat "$FINAL_SUBDOMAINS" 2>/dev/null | wc -l)
    print_result "Total In-Scope Subdomains (Post-Filter): ${GREEN}$FINAL_COUNT${NC}"
else
    print_warning "No Out-Of-Scope file provided. Skipping filtering."
fi

# ------------------------------------------------------------------------------
# Completion List
# ------------------------------------------------------------------------------
echo
print_status "${GREEN}=== EXTRACTION COMPLETE ===${NC}"
print_result "Final targets ready for n8n Flow 2."
print_result "Results saved to: ${YELLOW}$FINAL_SUBDOMAINS${NC}"
