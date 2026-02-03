#!/usr/bin/env bash
# Setup script for Maine EZPass Toll Monitor (Linux/macOS)
#
# Interactive setup to configure EZPass credentials and optional email/SMS notifications.
# Credentials are stored securely using the best available backend:
#   - macOS: Keychain
#   - Linux: pass (if available and initialized)
#   - Fallback: OpenSSL encrypted file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source credential helper
# shellcheck source=lib/credentials.sh
source "${SCRIPT_DIR}/lib/credentials.sh"

CONFIG_DIR="${HOME}/.ezpass"
CONFIG_JSON="${CONFIG_DIR}/config.json"

# Helper: read input with default
read_with_default() {
    local prompt="$1"
    local default="$2"
    local result
    if [[ -n "$default" ]]; then
        read -rp "${prompt} [${default}]: " result
        echo "${result:-$default}"
    else
        read -rp "${prompt}: " result
        echo "$result"
    fi
}

# Helper: read password (hidden input)
read_password() {
    local prompt="$1"
    local result
    read -rsp "${prompt}: " result
    echo ""  # newline after hidden input
    echo "$result"
}

# Helper: load existing JSON config
load_json_config() {
    if [[ -f "$CONFIG_JSON" ]]; then
        cat "$CONFIG_JSON"
    else
        echo '{}'
    fi
}

# Helper: get JSON value (simple parser for flat keys)
json_get() {
    local json="$1"
    local key="$2"
    echo "$json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    keys = '${key}'.split('.')
    v = d
    for k in keys:
        v = v[k]
    print(v)
except:
    print('')
" 2>/dev/null || echo ""
}

# ============================================================
# Banner
# ============================================================
echo "======================================================================"
echo "Maine EZPass Toll Monitor - Setup (Linux/macOS)"
echo "======================================================================"
echo ""
echo "Credential backend: $(get_backend_name)"
echo ""

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Check for existing config
is_update=false
existing_config="{}"

if [[ -f "$CONFIG_JSON" ]]; then
    echo "Configuration found!"
    echo "Current settings will be shown (passwords hidden)"
    echo "Press Enter to keep existing values, or type new values to update"
    echo ""

    read -rp "Continue with update? (yes/no): " continue_choice
    if [[ "$continue_choice" != "yes" ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    existing_config="$(load_json_config)"
    is_update=true
fi

# ============================================================
# EZPass Credentials
# ============================================================
echo ""
echo "======================================================================"
echo "EZPass Credentials"
echo "======================================================================"
echo ""

existing_user="$(get_password "ezpass-monitor/username" 2>/dev/null)" || true

if $is_update && [[ -n "$existing_user" ]]; then
    echo "Current username: ${existing_user}"
    echo ""
    read -rp "EZPass Username (press Enter to keep current): " username_input
    if [[ -z "$username_input" ]]; then
        username="$existing_user"
        echo "Keeping existing username"
    else
        username="$username_input"
    fi

    echo ""
    read -rp "Update password? (yes/no): " update_pass
    if [[ "$update_pass" == "yes" ]]; then
        password="$(read_password "EZPass Password")"
    else
        password="$(get_password "ezpass-monitor/password" 2>/dev/null)" || true
        echo "Keeping existing password"
    fi
else
    echo "Please enter your Maine EZPass credentials:"
    echo "(These will be stored securely via $(get_backend_name))"
    echo ""

    read -rp "EZPass Username: " username
    password="$(read_password "EZPass Password")"
fi

if [[ -z "$username" || -z "$password" ]]; then
    echo "Error: Username and password cannot be empty"
    exit 1
fi

# Save EZPass credentials
store_password "ezpass-monitor/username" "$username"
store_password "ezpass-monitor/password" "$password"

echo ""
echo "[OK] EZPass credentials saved"

# ============================================================
# Email Notifications (Optional)
# ============================================================
echo ""
echo "======================================================================"
echo "Email Notifications (Optional)"
echo "======================================================================"
echo ""

email_choice="2"
update_email=""
existing_smtp="$(json_get "$existing_config" "email.smtp_server")"

if $is_update && [[ -n "$existing_smtp" ]]; then
    existing_from="$(json_get "$existing_config" "email.from")"
    existing_to="$(json_get "$existing_config" "email.to")"
    existing_port="$(json_get "$existing_config" "email.port")"

    echo "Email is currently configured:"
    echo "  From: ${existing_from}"
    echo "  To: ${existing_to}"
    echo "  SMTP: ${existing_smtp}:${existing_port}"
    echo ""

    read -rp "Update email configuration? (yes/no/skip): " update_email

    if [[ "$update_email" == "skip" ]]; then
        email_choice="1"
        echo "Keeping existing email configuration"
    elif [[ "$update_email" == "yes" ]]; then
        email_choice="1"
    else
        email_choice="2"
    fi
else
    echo "Would you like to set up email notifications?"
    echo ""
    echo "  1. Yes - Configure email notifications"
    echo "  2. No - Skip email setup"
    echo ""

    read -rp "Enter choice (1-2): " email_choice
fi

smtp_server=""
smtp_port=587

if [[ "$email_choice" == "1" && "$update_email" != "skip" ]]; then
    # Provider selection
    echo ""
    echo "Select your email provider:"
    echo "  1. Gmail (recommended)"
    echo "  2. Outlook/Hotmail"
    echo "  3. Yahoo"
    echo "  4. Other (custom SMTP)"
    echo ""

    read -rp "Enter choice (1-4): " provider

    case "$provider" in
        1)
            smtp_server="smtp.gmail.com"
            echo ""
            echo "Gmail Setup Instructions:"
            echo "1. Enable 2-Factor Authentication on your Google account"
            echo "2. Go to: https://myaccount.google.com/apppasswords"
            echo "3. Create an App Password for 'Mail'"
            echo "4. Use the 16-character password below (NOT your Gmail password)"
            echo ""
            ;;
        2)
            smtp_server="smtp.office365.com"
            echo ""
            echo "Outlook/Hotmail: Use your regular account password"
            echo ""
            ;;
        3)
            smtp_server="smtp.mail.yahoo.com"
            echo ""
            echo "Yahoo Setup Instructions:"
            echo "1. Go to Yahoo Account Security settings"
            echo "2. Generate an App Password"
            echo "3. Use the app password below (NOT your Yahoo password)"
            echo ""
            ;;
        4)
            echo ""
            read -rp "SMTP Server address: " smtp_server
            read -rp "SMTP Port (default: 587): " port_input
            if [[ -n "$port_input" ]]; then
                smtp_port=$port_input
            fi
            ;;
        *)
            echo "Invalid choice, skipping email setup"
            email_choice="2"
            ;;
    esac

    if [[ "$email_choice" == "1" ]]; then
        # Get email addresses
        echo ""
        read -rp "Your email address: " from_email
        read -rp "Send notifications to (press Enter for same address): " to_email

        if [[ -z "$to_email" ]]; then
            to_email="$from_email"
        fi

        # Get password
        echo ""
        email_password="$(read_password "Email password (or App Password)")"

        # Store email password securely
        store_password "ezpass-monitor/email-password" "$email_password"

        # Notification preferences
        echo ""
        echo "Notification preferences:"
        echo "  1. All tiers (always notify)"
        echo "  2. Only Bronze + Gold (20% and 40% discount tiers)"
        echo "  3. Only Gold (40% discount tier only)"
        echo "  4. Only when no discount"
        echo ""

        read -rp "Enter choice (1-4, default: 1): " tier_choice

        case "$tier_choice" in
            2) only_alert_on_tiers="Bronze,Gold" ;;
            3) only_alert_on_tiers="Gold" ;;
            4) only_alert_on_tiers="None" ;;
            *) only_alert_on_tiers="" ;;
        esac

        echo ""
        echo "[OK] Email configuration saved"
    fi
else
    if [[ "$email_choice" != "1" ]]; then
        echo ""
        echo "Email setup skipped"
    fi
fi

# ============================================================
# SMS Notifications (Optional)
# ============================================================
echo ""
echo "======================================================================"
echo "SMS Notifications (Optional)"
echo "======================================================================"
echo ""

sms_choice="2"
update_sms=""
existing_sms_to="$(json_get "$existing_config" "sms.to")"

if $is_update && [[ -n "$existing_sms_to" ]]; then
    existing_carrier="$(json_get "$existing_config" "sms.carrier")"

    echo "SMS is currently configured:"
    echo "  To: ${existing_sms_to}"
    echo "  Carrier: ${existing_carrier}"
    echo ""

    read -rp "Update SMS configuration? (yes/no/skip): " update_sms

    if [[ "$update_sms" == "skip" ]]; then
        sms_choice="1"
        echo "Keeping existing SMS configuration"
    elif [[ "$update_sms" == "yes" ]]; then
        sms_choice="1"
    else
        sms_choice="2"
    fi
else
    if [[ -n "$smtp_server" ]] || [[ -n "$existing_smtp" ]]; then
        echo "Would you like to set up SMS notifications?"
        echo "Note: SMS uses email-to-SMS gateways (requires email config above)"
        echo ""
        echo "  1. Yes - Configure SMS notifications"
        echo "  2. No - Skip SMS setup"
        echo ""

        read -rp "Enter choice (1-2): " sms_choice
    else
        echo "SMS requires email configuration (uses SMTP for email-to-SMS gateways)"
        echo "Email was not configured, skipping SMS setup"
        sms_choice="2"
    fi
fi

sms_address=""
sms_carrier=""
sms_only_alert_on_tiers=""

if [[ "$sms_choice" == "1" && "$update_sms" != "skip" ]] && { [[ -n "$smtp_server" ]] || [[ -n "$existing_smtp" ]]; }; then
    # Carrier selection
    echo ""
    echo "Select your mobile carrier:"
    echo "  1. Verizon"
    echo "  2. AT&T"
    echo "  3. T-Mobile"
    echo "  4. Sprint"
    echo "  5. Other (enter custom gateway)"
    echo ""

    read -rp "Enter choice (1-5): " carrier_choice

    sms_gateway=""
    case "$carrier_choice" in
        1) sms_gateway="@vtext.com"; sms_carrier="Verizon" ;;
        2) sms_gateway="@txt.att.net"; sms_carrier="AT&T" ;;
        3) sms_gateway="@tmomail.net"; sms_carrier="T-Mobile" ;;
        4) sms_gateway="@messaging.sprintpcs.com"; sms_carrier="Sprint" ;;
        5)
            echo ""
            read -rp "Email-to-SMS gateway (e.g., @carrier.com): " sms_gateway
            if [[ "${sms_gateway:0:1}" != "@" ]]; then
                sms_gateway="@${sms_gateway}"
            fi
            sms_carrier="Custom"
            ;;
        *)
            echo "Invalid choice, skipping SMS setup"
            sms_choice="2"
            ;;
    esac

    if [[ "$sms_choice" == "1" ]]; then
        echo ""
        read -rp "Your 10-digit phone number (digits only): " phone_number

        # Clean phone number
        phone_number=$(echo "$phone_number" | tr -dc '0-9')

        if [[ ${#phone_number} -ne 10 ]]; then
            echo "Invalid phone number, skipping SMS setup"
            sms_choice="2"
        else
            sms_address="${phone_number}${sms_gateway}"

            # SMS notification preferences
            echo ""
            echo "SMS notification preferences:"
            echo "  1. All tiers (always notify)"
            echo "  2. Only Bronze + Gold (20% and 40% discount tiers)"
            echo "  3. Only Gold (40% discount tier only)"
            echo "  4. Only when no discount"
            echo ""

            read -rp "Enter choice (1-4, default: 1): " sms_tier_choice

            case "$sms_tier_choice" in
                2) sms_only_alert_on_tiers="Bronze,Gold" ;;
                3) sms_only_alert_on_tiers="Gold" ;;
                4) sms_only_alert_on_tiers="None" ;;
                *) sms_only_alert_on_tiers="" ;;
            esac

            echo ""
            echo "[OK] SMS configuration saved"
            echo "SMS will be sent to: ${sms_address}"
        fi
    fi
else
    if [[ "$sms_choice" != "1" ]]; then
        echo ""
        echo "SMS setup skipped"
    fi
fi

# ============================================================
# Save Configuration (non-sensitive settings as JSON)
# ============================================================
echo ""
echo "======================================================================"
echo "Saving configuration..."
echo "======================================================================"

# Build JSON config (non-sensitive settings only)
# Passwords are stored in the credential backend, not here
{
    echo "{"

    # Email config (if set or preserved)
    if [[ -n "$smtp_server" ]]; then
        echo "  \"email\": {"
        echo "    \"smtp_server\": \"${smtp_server}\","
        echo "    \"port\": ${smtp_port},"
        echo "    \"from\": \"${from_email}\","
        echo "    \"to\": \"${to_email}\","
        echo "    \"username\": \"${from_email}\","
        echo "    \"use_ssl\": true,"
        echo "    \"only_alert_on_tiers\": \"${only_alert_on_tiers}\""
        echo "  },"
    elif [[ -n "$existing_smtp" && "$email_choice" != "2" ]]; then
        # Preserve existing email config
        echo "$existing_config" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'email' in d:
    print('  \"email\": ' + json.dumps(d['email'], indent=4) + ',')
" 2>/dev/null || true
    fi

    # SMS config (if set or preserved)
    if [[ -n "$sms_address" ]]; then
        echo "  \"sms\": {"
        echo "    \"to\": \"${sms_address}\","
        echo "    \"carrier\": \"${sms_carrier}\","
        echo "    \"only_alert_on_tiers\": \"${sms_only_alert_on_tiers}\""
        echo "  },"
    elif [[ -n "$existing_sms_to" && "$sms_choice" != "2" ]]; then
        # Preserve existing SMS config
        echo "$existing_config" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'sms' in d:
    print('  \"sms\": ' + json.dumps(d['sms'], indent=4) + ',')
" 2>/dev/null || true
    fi

    echo "  \"version\": 1"
    echo "}"
} > "$CONFIG_JSON"

chmod 600 "$CONFIG_JSON"

echo ""
echo "[OK] Configuration saved to: ${CONFIG_JSON}"
echo ""
echo "Security Note:"
echo "Credentials are stored securely via $(get_backend_name)"
echo "Non-sensitive settings (SMTP server, addresses) are in: ${CONFIG_JSON}"
echo ""

# ============================================================
# Test Connection
# ============================================================
echo ""
echo "======================================================================"
echo "Testing EZPass connection..."
echo "======================================================================"
echo ""

set +e
"${SCRIPT_DIR}/check-tolls.sh" --estimate
exit_code=$?
set -e

if [[ $exit_code -eq 1 || $exit_code -eq 2 || $exit_code -eq 3 ]]; then
    echo ""
    echo "======================================================================"
    echo "[OK] EZPass connection successful!"
    echo "======================================================================"

    # Test email if configured and updated
    if [[ "$email_choice" == "1" && "$update_email" != "skip" ]]; then
        echo ""
        read -rp "Would you like to send a test email? (yes/no): " test_email

        if [[ "$test_email" == "yes" ]]; then
            echo ""
            echo "Sending test email..."

            set +e
            "${SCRIPT_DIR}/notify-email.sh"
            email_result=$?
            set -e

            if [[ $email_result -eq 0 ]]; then
                echo ""
                echo "[OK] Test email sent!"
                echo "Check your inbox at: ${to_email:-$(json_get "$existing_config" "email.to")}"
            else
                echo ""
                echo "WARNING: Test email failed"
                echo ""
                echo "Common issues:"
                echo "  - Gmail: Make sure you created an App Password (not regular password)"
                echo "  - Check your email address and password are correct"
                echo "  - Try running: ./notify-email.sh to test again"
            fi
        fi
    fi

    # Test SMS if configured and updated
    if [[ "$sms_choice" == "1" && "$update_sms" != "skip" ]]; then
        echo ""
        read -rp "Would you like to send a test SMS? (yes/no): " test_sms

        if [[ "$test_sms" == "yes" ]]; then
            echo ""
            echo "Sending test SMS..."

            set +e
            "${SCRIPT_DIR}/notify-sms.sh"
            sms_result=$?
            set -e

            if [[ $sms_result -eq 0 ]]; then
                echo ""
                echo "[OK] Test SMS sent!"
                echo "Check your phone at: ${sms_address:-$(json_get "$existing_config" "sms.to")}"
            else
                echo ""
                echo "WARNING: Test SMS failed"
                echo ""
                echo "Common issues:"
                echo "  - Verify your carrier's email-to-SMS gateway is correct"
                echo "  - Some carriers may have delays (wait 1-2 minutes)"
                echo "  - Try running: ./notify-sms.sh to test again"
            fi
        fi
    fi

    echo ""
    echo "======================================================================"
    echo "Setup Complete!"
    echo "======================================================================"
    echo ""
    echo "You can now run:"
    echo "  ./check-tolls.sh --estimate              # Check your tolls"
    echo "  ./check-tolls.sh --estimate --sms-format  # Check in SMS format"

    if [[ -n "$smtp_server" ]] || [[ -n "$existing_smtp" ]]; then
        echo "  ./notify-email.sh                        # Send email notification"
    fi

    if [[ -n "$sms_address" ]] || [[ -n "$existing_sms_to" ]]; then
        echo "  ./notify-sms.sh                          # Send SMS notification"
    fi

    echo ""
    echo "See README.md for automation instructions"
    echo ""
else
    echo ""
    echo "WARNING: Setup completed but there was an issue with the test."
    echo "Please check your credentials and try again."
fi
