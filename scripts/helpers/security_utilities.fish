#!/usr/bin/fish
# Security utilities for FastWrt scripts - helps mask sensitive information

# List of patterns to mask in normal output
# Format: "pattern_to_match|replacement_text"
set SENSITIVE_PATTERNS
set -a SENSITIVE_PATTERNS "private_key=.*|private_key=[MASKED]"
set -a SENSITIVE_PATTERNS "public_key=.*|public_key=[MASKED]"
set -a SENSITIVE_PATTERNS "key=.*|key=[MASKED]"
set -a SENSITIVE_PATTERNS "psk=.*|psk=[MASKED]"
set -a SENSITIVE_PATTERNS "password=.*|password=[MASKED]"

# Function to mask sensitive information in UCI output
function mask_sensitive_uci_output
    # If debug mode is enabled, do not mask
    if test "$DEBUG" = "true"
        cat
    else
        # Process input and mask sensitive information
        set input (cat)
        for pattern in $SENSITIVE_PATTERNS
            set match_pattern (echo $pattern | cut -d"|" -f1)
            set replace_text (echo $pattern | cut -d"|" -f2)
            set input (echo $input | sed -r "s/$match_pattern/$replace_text/g")
        end
        echo $input
    end
end

# Function to mask WireGuard configuration output
function mask_wireguard_config
    if test "$DEBUG" = "true"
        cat
    else
        # Filter WireGuard-specific info
        grep -v "private_key=" | grep -v "public_key="
    end
end

# Function to sanitize UCI changes output for display in non-debug mode
function sanitize_uci_changes
    set config $argv[1]
    if test "$DEBUG" = "true"
        # Show everything in debug mode
        uci changes $config
    else
        # In non-debug mode, filter sensitive information
        uci changes $config | grep -v "private_key=" | grep -v "public_key=" | \
        grep -v "psk=" | grep -v "key=" | sed 's/\(password=\)[^ ]*/\1[MASKED]/g'
        echo "$yellow""Note: Some sensitive configuration details are masked in normal mode""$reset"
        echo "$yellow""Use --debug flag to see complete configuration""$reset"
    end
end

# Export as functions that can be used in other scripts
functions -q mask_sensitive_uci_output
functions -q mask_wireguard_config
functions -q sanitize_uci_changes
