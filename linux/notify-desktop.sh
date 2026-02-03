#!/usr/bin/env bash
# Desktop notification for Maine EZPass Toll Monitor (Linux/macOS)
#
# Uses notify-send (Linux) or osascript (macOS) for desktop notifications.
# Falls back to terminal output if neither is available.
#
# Usage:
#   ./notify-desktop.sh
#   ./notify-desktop.sh --only-alert-on-tiers "Bronze,Gold"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
ONLY_ALERT_ON_TIERS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only-alert-on-tiers) ONLY_ALERT_ON_TIERS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --only-alert-on-tiers TIERS  Only show notification for specific tiers"
            echo "                               (comma-separated: None,Bronze,Gold)"
            echo "  -h, --help                   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Run the toll check and capture output
echo "Running toll check..."
set +e
output=$("${SCRIPT_DIR}/check-tolls.sh" --estimate 2>&1)
exit_code=$?
set -e

# Display the output
echo "$output"

# Check for specific errors
service_unavailable=false
toll_check_failed=false

if echo "$output" | grep -qi "currently unavailable\|service is currently unavailable"; then
    service_unavailable=true
    toll_check_failed=true
elif echo "$output" | grep -qi "No toll data retrieved\|Error:\|Login failed\|Login still failed"; then
    toll_check_failed=true
fi

# Determine notification content based on tier/errors
if $toll_check_failed; then
    if $service_unavailable; then
        notif_title="EZPass Service Unavailable"
        notif_message="The Maine EZPass service is temporarily down. Try again later."
        notif_urgency="normal"
        tier_name="Service Unavailable"
    else
        notif_title="EZPass Monitor Error"
        notif_message="Failed to retrieve toll data. Check your connection or credentials."
        notif_urgency="critical"
        tier_name="Error"
    fi
else
    case "$exit_code" in
        3)
            tier_name="None"
            notif_title="No Discount Tier"
            notif_message="On track for 0-29 tolls - no discount"
            notif_urgency="critical"
            ;;
        2)
            tier_name="Bronze"
            notif_title="Bronze Tier - 20% Discount"
            notif_message="On track for 30-39 tolls - 20% discount!"
            notif_urgency="normal"
            ;;
        1)
            tier_name="Gold"
            notif_title="Gold Tier - 40% Discount"
            notif_message="On track for 40+ tolls - maximum 40% discount!"
            notif_urgency="low"
            ;;
        *)
            tier_name="Unknown"
            notif_title="EZPass Monitor Error"
            notif_message="Error checking toll count"
            notif_urgency="critical"
            ;;
    esac
fi

# Check if we should show notification for this tier
should_notify=true
if [[ -n "$ONLY_ALERT_ON_TIERS" ]]; then
    if ! echo "$ONLY_ALERT_ON_TIERS" | grep -q "$tier_name"; then
        should_notify=false
    fi
fi

if ! $should_notify; then
    echo ""
    echo "INFO: No notification shown (tier '${tier_name}' not in alert list)"
    exit 0
fi

# Extract toll count from output
toll_count="Unknown"
if echo "$output" | grep -qP "Estimated month-end discount-eligible tolls: [\d.]+"; then
    toll_count=$(echo "$output" | grep -oP "Estimated month-end discount-eligible tolls: [\d.]+" | grep -oP "[\d.]+$" | awk '{ printf "%.0f", $1 }')
elif echo "$output" | grep -qP "Discount-eligible tolls: \d+"; then
    toll_count=$(echo "$output" | grep -oP "Discount-eligible tolls: \d+" | grep -oP "\d+$")
fi

detailed_message="${notif_message}

Projected tolls: ${toll_count}"

# Send notification using the best available method
os_type="$(uname -s)"
notif_sent=false

if [[ "$os_type" == "Linux" ]]; then
    # Linux: try notify-send (libnotify)
    if command -v notify-send &>/dev/null; then
        notify-send \
            --urgency="$notif_urgency" \
            --app-name="Maine EZPass Monitor" \
            "Maine EZPass Monitor - ${notif_title}" \
            "Projected tolls: ${toll_count}" 2>/dev/null && notif_sent=true
    fi
elif [[ "$os_type" == "Darwin" ]]; then
    # macOS: use osascript
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"${notif_message} (Projected: ${toll_count} tolls)\" with title \"Maine EZPass Monitor\" subtitle \"${notif_title}\"" 2>/dev/null && notif_sent=true
    fi
fi

if $notif_sent; then
    echo ""
    echo "[OK] Desktop notification displayed!"
else
    # Fallback to terminal output
    echo ""
    echo "======================================"
    echo "  Maine EZPass Monitor"
    echo "  ${notif_title}"
    echo "--------------------------------------"
    echo "  ${notif_message}"
    echo "  Projected tolls: ${toll_count}"
    echo "======================================"
    echo ""
    echo "(Desktop notification not available - install 'libnotify' or use macOS)"
fi

exit 0
