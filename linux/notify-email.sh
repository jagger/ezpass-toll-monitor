#!/usr/bin/env bash
# Email notification wrapper for Maine EZPass Toll Monitor (Linux/macOS)
#
# Runs the toll check and sends results via email using curl SMTP.
# Reads configuration from ~/.ezpass/config.json and credential store.

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

# Check if email is configured
smtp_server="$(json_get "email.smtp_server")"
if [[ -z "$smtp_server" ]]; then
    echo "Error: Email not configured"
    echo "Run ./setup.sh and configure email settings"
    exit 1
fi

# Extract email config
smtp_port="$(json_get "email.port")"
from_email="$(json_get "email.from")"
to_email="$(json_get "email.to")"
email_username="$(json_get "email.username")"
use_ssl="$(json_get "email.use_ssl")"
only_alert_on_tiers="$(json_get "email.only_alert_on_tiers")"

# Get email password from credential store
email_password="$(get_password "ezpass-monitor/email-password" 2>/dev/null)" || true
if [[ -z "$email_password" ]]; then
    echo "Error: Email password not found in credential store"
    echo "Run ./setup.sh to reconfigure email settings"
    exit 1
fi

# Run the toll check and capture output
echo "Running toll check..."
set +e
body_text=$("${SCRIPT_DIR}/check-tolls.sh" --estimate --email-output 2>&1)
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
    echo "WARNING: EZPass service unavailable - sending notification"
elif echo "$body_text" | grep -qi "No toll data retrieved\|Error:\|Login failed\|Login still failed"; then
    toll_check_failed=true
    echo ""
    echo "WARNING: Toll check failed - sending error notification"
fi

# Determine discount tier from exit code
case "$exit_code" in
    3) tier_name="None" ;;
    2) tier_name="Bronze" ;;
    1) tier_name="Gold" ;;
    *) tier_name="Unknown" ;;
esac

# Check if we should send notification for this tier
should_notify=true
if ! $toll_check_failed && [[ -n "$only_alert_on_tiers" ]]; then
    if ! echo "$only_alert_on_tiers" | grep -q "$tier_name"; then
        should_notify=false
    fi
fi

if ! $should_notify; then
    echo ""
    echo "INFO: No notification sent (tier '${tier_name}' not in alert list)"
    exit 0
fi

# Extract total amount from body for subject line
total_amount="0.00"
toll_amounts=$(echo "$body_text" | grep -oP 'Toll: \$([0-9.]+)' | grep -oP '[0-9.]+' || true)
if [[ -n "$toll_amounts" ]]; then
    total_amount=$(echo "$toll_amounts" | awk '{ sum += $1 } END { printf "%.2f", sum }')
fi

# Determine email subject
if $toll_check_failed; then
    if $service_unavailable; then
        subject="EZPass Monitor - Service Currently Unavailable"
    else
        subject="EZPass Monitor Error - Failed to retrieve toll data"
    fi
else
    case "$exit_code" in
        3)
            max_savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.40 }")
            subject="EZPass Alert: No Discount - Potential \$${max_savings} savings with Gold"
            ;;
        2)
            current_savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.20 }")
            max_savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.40 }")
            additional_savings=$(awk "BEGIN { printf \"%.2f\", $max_savings - $current_savings }")
            subject="EZPass Alert: Bronze (20%) - \$${additional_savings} more with Gold"
            ;;
        1)
            max_savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.40 }")
            subject="EZPass Alert: Gold (40%) - Saving \$${max_savings} this month!"
            ;;
        *)
            subject="EZPass Monitor Error - Unknown status"
            ;;
    esac
fi

# Send email via curl SMTP
echo ""
echo "Sending email notification..."
echo "  From: ${from_email}"
echo "  To: ${to_email}"
echo "  Subject: ${subject}"

# Build the email message
email_msg="From: ${from_email}
To: ${to_email}
Subject: ${subject}
Content-Type: text/plain; charset=UTF-8

${body_text}"

# Determine SMTP URL based on port
if [[ "$smtp_port" == "465" ]]; then
    smtp_url="smtps://${smtp_server}:${smtp_port}"
else
    smtp_url="smtp://${smtp_server}:${smtp_port}"
fi

# Send via curl
curl_args=(
    --url "$smtp_url"
    --mail-from "$from_email"
    --mail-rcpt "$to_email"
    --user "${email_username}:${email_password}"
    -T -
)

if [[ "$smtp_port" != "465" ]] && [[ "$use_ssl" == "True" || "$use_ssl" == "true" || "$use_ssl" == "1" ]]; then
    curl_args+=(--ssl-reqd)
fi

if echo "$email_msg" | curl -s "${curl_args[@]}"; then
    echo "[OK] Email sent successfully!"
else
    echo "Error sending email" >&2
    echo ""
    echo "Common issues:"
    echo "  - Gmail users: Enable 2FA and create an App Password"
    echo "  - Outlook/Hotmail: smtp.office365.com, port 587"
    echo "  - Yahoo: smtp.mail.yahoo.com, port 587"
    exit 1
fi

exit 0
