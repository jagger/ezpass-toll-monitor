#!/usr/bin/env bash
# Credential storage helper for Maine EZPass Toll Monitor
# Detects platform and available tools, provides unified credential API
#
# Supported backends (in priority order):
#   1. macOS Keychain (security command)
#   2. pass (standard Unix password manager)
#   3. OpenSSL encrypted file fallback

EZPASS_CONFIG_DIR="${HOME}/.ezpass"
EZPASS_CONFIG_ENC="${EZPASS_CONFIG_DIR}/config.enc"

# Detect platform and available credential backend
_detect_backend() {
    local os
    os="$(uname -s)"

    if [[ "$os" == "Darwin" ]]; then
        # macOS - use Keychain
        if command -v security &>/dev/null; then
            echo "keychain"
            return
        fi
    fi

    # Linux / other - try pass first
    if command -v pass &>/dev/null; then
        # Check if pass is initialized
        if pass ls &>/dev/null 2>&1; then
            echo "pass"
            return
        fi
    fi

    # Fallback to openssl encrypted file
    if command -v openssl &>/dev/null; then
        echo "openssl"
        return
    fi

    echo "none"
}

CRED_BACKEND="$(_detect_backend)"

# Store a password in the credential store
# Usage: store_password <service> <value>
# service: e.g. "ezpass-monitor/account" or "ezpass-monitor/email"
store_password() {
    local service="$1"
    local value="$2"

    if [[ -z "$service" || -z "$value" ]]; then
        echo "Error: store_password requires <service> and <value>" >&2
        return 1
    fi

    mkdir -p "$EZPASS_CONFIG_DIR"
    chmod 700 "$EZPASS_CONFIG_DIR"

    case "$CRED_BACKEND" in
        keychain)
            # macOS Keychain
            security delete-generic-password -s "$service" -a "ezpass-monitor" 2>/dev/null
            security add-generic-password -s "$service" -a "ezpass-monitor" -w "$value" -U
            ;;
        pass)
            # pass (standard Unix password manager)
            echo "$value" | pass insert -f "$service" 2>/dev/null
            ;;
        openssl)
            # OpenSSL encrypted file
            # Read existing secrets, update, re-encrypt
            local tmpfile
            tmpfile="$(mktemp)"
            trap "rm -f '$tmpfile'" RETURN

            if [[ -f "$EZPASS_CONFIG_ENC" ]]; then
                # Decrypt existing file
                if ! _openssl_decrypt > "$tmpfile" 2>/dev/null; then
                    # If decrypt fails, start fresh
                    : > "$tmpfile"
                fi
            fi

            # Remove old entry for this service, add new one
            grep -v "^${service}=" "$tmpfile" 2>/dev/null > "${tmpfile}.new" || true
            echo "${service}=${value}" >> "${tmpfile}.new"
            mv "${tmpfile}.new" "$tmpfile"

            # Encrypt and save
            _openssl_encrypt < "$tmpfile"
            chmod 600 "$EZPASS_CONFIG_ENC"
            ;;
        *)
            echo "Error: No supported credential backend found" >&2
            echo "Install 'pass' or 'openssl' for credential storage" >&2
            return 1
            ;;
    esac
}

# Retrieve a password from the credential store
# Usage: get_password <service>
# Returns password on stdout, empty string if not found
get_password() {
    local service="$1"

    if [[ -z "$service" ]]; then
        echo "Error: get_password requires <service>" >&2
        return 1
    fi

    case "$CRED_BACKEND" in
        keychain)
            security find-generic-password -s "$service" -a "ezpass-monitor" -w 2>/dev/null
            ;;
        pass)
            pass show "$service" 2>/dev/null | head -1
            ;;
        openssl)
            if [[ ! -f "$EZPASS_CONFIG_ENC" ]]; then
                return 1
            fi
            local decrypted
            decrypted="$(_openssl_decrypt 2>/dev/null)" || return 1
            echo "$decrypted" | grep "^${service}=" | head -1 | cut -d'=' -f2-
            ;;
        *)
            return 1
            ;;
    esac
}

# Delete a password from the credential store
# Usage: delete_password <service>
delete_password() {
    local service="$1"

    case "$CRED_BACKEND" in
        keychain)
            security delete-generic-password -s "$service" -a "ezpass-monitor" 2>/dev/null
            ;;
        pass)
            pass rm -f "$service" 2>/dev/null
            ;;
        openssl)
            if [[ ! -f "$EZPASS_CONFIG_ENC" ]]; then
                return 0
            fi
            local tmpfile
            tmpfile="$(mktemp)"
            trap "rm -f '$tmpfile'" RETURN

            if _openssl_decrypt > "$tmpfile" 2>/dev/null; then
                grep -v "^${service}=" "$tmpfile" > "${tmpfile}.new" || true
                if [[ -s "${tmpfile}.new" ]]; then
                    _openssl_encrypt < "${tmpfile}.new"
                else
                    rm -f "$EZPASS_CONFIG_ENC"
                fi
                rm -f "${tmpfile}.new"
            fi
            ;;
    esac
}

# Internal: get the encryption passphrase for openssl fallback
# Uses a machine-specific key derived from hostname + user
_openssl_passphrase() {
    local host user
    host="$(hostname 2>/dev/null || echo "localhost")"
    user="$(whoami 2>/dev/null || echo "user")"
    echo "ezpass-${user}@${host}-credential-store"
}

# Internal: decrypt the openssl config file to stdout
_openssl_decrypt() {
    local pass
    pass="$(_openssl_passphrase)"
    openssl enc -aes-256-cbc -d -pbkdf2 -in "$EZPASS_CONFIG_ENC" -pass "pass:${pass}" 2>/dev/null
}

# Internal: encrypt stdin to the openssl config file
_openssl_encrypt() {
    local pass
    pass="$(_openssl_passphrase)"
    openssl enc -aes-256-cbc -pbkdf2 -salt -out "$EZPASS_CONFIG_ENC" -pass "pass:${pass}" 2>/dev/null
}

# Get the name of the active backend (for display purposes)
get_backend_name() {
    case "$CRED_BACKEND" in
        keychain) echo "macOS Keychain" ;;
        pass) echo "pass (Unix password manager)" ;;
        openssl) echo "OpenSSL encrypted file" ;;
        *) echo "none" ;;
    esac
}
