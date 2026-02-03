#!/usr/bin/env bash
# SMS notification wrapper for Maine EZPass Toll Monitor (Linux/macOS)
#
# Runs the toll check with SMS format and sends compact text message
# via email-to-SMS carrier gateway using curl SMTP.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source credential helper
# shellcheck source=lib/credentials.sh
source "${SCRIPT_DIR}/lib/credentials.sh"

CONFIG_DIR="${HOME}/.ezpass"
CONFIG_JSON="${CONFIG_DIR}/config.json"

# Load config
if [[ ! -f "$CONFIG_JSON" ]]; then
    echo "Error: Configuration not found"
    echo "Run ./setup.sh first to configure your settings"
    exit 1
fi

# Helper: get JSON value
json_get() {
    local key="$1"
    python3 -c "
import json, sys
try:
    with open('${CONFIG_JSON}') as f:
        d = json.load(f)
    keys = '${key}'.split('.')
    v = d
    for k in keys:
        v = v[k]
    print(v)
except:
    print('')
" 2>/dev/null || echo ""
}

# Check if SMS is configured
sms_to="$(json_get "sms.to")"
if [[ -z "$sms_to" ]]; then
    echo "Error: SMS not configured"
    echo "Run ./setup.sh and configure SMS settings"
    exit 1
fi

# Extract email config (SMS uses SMTP)
smtp_server="$(json_get "email.smtp_server")"
smtp_port="$(json_get "email.port")"
from_email="$(json_get "email.from")"
email_username="$(json_get "email.username")"
use_ssl="$(json_get "email.use_ssl")"
sms_only_alert_on_tiers="$(json_get "sms.only_alert_on_tiers")"

if [[ -z "$smtp_server" ]]; then
    echo "Error: Email configuration required for SMS (uses SMTP)"
    echo "Run ./setup.sh and configure email settings"
    exit 1
fi

# Get email password from credential store
email_password="$(get_password "ezpass-monitor/email-password" 2>/dev/null)" || true
if [[ -z "$email_password" ]]; then
    echo "Error: Email password not found in credential store"
    echo "Run ./setup.sh to reconfigure email settings"
    exit 1
fi

# Run the toll check with SMS format
echo "Running toll check..."
set +e
body_text=$("${SCRIPT_DIR}/check-tolls.sh" --estimate --sms-format 2>&1)
exit_code=$?
set -e

if [[ -z "$body_text" ]]; then
    body_text="Toll check completed with exit code: ${exit_code}\nNo toll data retrieved."
fi

# Display to console
echo ""
echo "$body_text"
echo ""

# Check if toll check succeeded or failed
toll_check_failed=false
service_unavailable=false

if echo "$body_text" | grep -qi "currently unavailable\|service is currently unavailable"; then
    toll_check_failed=true
    service_unavailable=true
    echo ""
    echo "WARNING: EZPass service unavailable - sending SMS notification"
elif echo "$body_text" | grep -qi "No toll data retrieved\|Error:\|Login failed\|Login still failed"; then
    toll_check_failed=true
    echo ""
    echo "WARNING: Toll check failed - sending error SMS notification"
fi

# Determine if we should send notification based on tier filter
should_notify=true
if ! $toll_check_failed && [[ -n "$sms_only_alert_on_tiers" ]]; then
    case "$exit_code" in
        3) tier_name="None" ;;
        2) tier_name="Bronze" ;;
        1) tier_name="Gold" ;;
        *) tier_name="Unknown" ;;
    esac

    if ! echo "$sms_only_alert_on_tiers" | grep -q "$tier_name"; then
        should_notify=false
    fi
fi

if ! $should_notify; then
    echo ""
    echo "INFO: No SMS sent (tier not in alert list)"
    exit 0
fi

# Prepare SMS subject
if $toll_check_failed; then
    if $service_unavailable; then
        subject="EZPass: Service Down"
    else
        subject="EZPass: Error"
    fi
else
    subject="EZPass Status"
fi

# Send SMS via email-to-SMS gateway using curl SMTP
echo ""
echo "Sending SMS notification..."
echo "  To: ${sms_to}"
echo "  Via: ${smtp_server}"

# Build the email message
email_msg="From: ${from_email}
To: ${sms_to}
Subject: ${subject}
Content-Type: text/plain; charset=UTF-8

${body_text}"

# Determine SMTP URL
if [[ "$smtp_port" == "465" ]]; then
    smtp_url="smtps://${smtp_server}:${smtp_port}"
else
    smtp_url="smtp://${smtp_server}:${smtp_port}"
fi

# Send via curl
curl_args=(
    --url "$smtp_url"
    --mail-from "$from_email"
    --mail-rcpt "$sms_to"
    --user "${email_username}:${email_password}"
    -T -
)

if [[ "$smtp_port" != "465" ]] && [[ "$use_ssl" == "True" || "$use_ssl" == "true" || "$use_ssl" == "1" ]]; then
    curl_args+=(--ssl-reqd)
fi

if echo "$email_msg" | curl -s "${curl_args[@]}"; then
    echo "[OK] SMS sent successfully!"
else
    echo "Error sending SMS" >&2
    echo ""
    echo "Common issues:"
    echo "  - Check your carrier's email-to-SMS gateway address"
    echo "  - Ensure email credentials are configured (uses Email config)"
    echo "  - Some carriers may block email-to-SMS from certain providers"
    exit 1
fi

exit 0
