#!/usr/bin/env bash
# Maine EZPass Toll Monitor for Linux/macOS
#
# Checks if you're on track to post fewer than 40 discount-eligible tolls in a month.
# Having 40+ tolls triggers a 40% discount (Gold tier).
#
# Usage:
#   ./check-tolls.sh --estimate
#   ./check-tolls.sh --username "user" --password "pass" --save-config
#   ./check-tolls.sh --verbose --download
#   ./check-tolls.sh --month 12 --year 2025
#
# Exit codes:
#   0 = Discount verified (match) when using --verify-discount
#   1 = Gold tier (40+ tolls)
#   2 = Bronze tier (30-39 tolls)
#   3 = No discount tier (0-29 tolls)
#   4 = Discount mismatch when using --verify-discount

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source credential helper
# shellcheck source=lib/credentials.sh
source "${SCRIPT_DIR}/lib/credentials.sh"

# Config
CONFIG_DIR="${HOME}/.ezpass"
CONFIG_JSON="${CONFIG_DIR}/config.json"
COOKIE_FILE="${CONFIG_DIR}/cookies.txt"
SESSION_MAX_AGE=600  # 10 minutes in seconds
BASE_URL="https://ezpassmaineturnpike.com"

# Defaults
USERNAME=""
PASSWORD=""
MONTH=""
YEAR=""
ESTIMATE=false
VERBOSE=false
SAVE_CONFIG=false
DOWNLOAD_FILE=false
EMAIL_OUTPUT=false
SMS_FORMAT=false
VERIFY_DISCOUNT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)  USERNAME="$2"; shift 2 ;;
        --password)  PASSWORD="$2"; shift 2 ;;
        --month)     MONTH="$2"; shift 2 ;;
        --year)      YEAR="$2"; shift 2 ;;
        --estimate)  ESTIMATE=true; shift ;;
        --verbose)   VERBOSE=true; shift ;;
        --save-config) SAVE_CONFIG=true; shift ;;
        --download)  DOWNLOAD_FILE=true; shift ;;
        --email-output) EMAIL_OUTPUT=true; shift ;;
        --sms-format) SMS_FORMAT=true; shift ;;
        --verify-discount) VERIFY_DISCOUNT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --username USER    EZPass username"
            echo "  --password PASS    EZPass password"
            echo "  --month MM         Month to check (1-12, default: current)"
            echo "  --year YYYY        Year to check (default: current)"
            echo "  --estimate         Project month-end totals"
            echo "  --verbose          Show detailed debug output"
            echo "  --save-config      Save credentials to secure config"
            echo "  --download         Save CSV data to file"
            echo "  --email-output     Format output for email capture"
            echo "  --sms-format       Compact SMS-friendly output"
            echo "  --verify-discount AMT  Verify EZPass discount matches toll data"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Helper: verbose logging
vlog() {
    if $VERBOSE; then
        echo "[VERBOSE] $*" >&2
    fi
}

# Helper: colored output (skipped in email mode)
color_echo() {
    local color="$1"
    shift
    if $EMAIL_OUTPUT; then
        echo "$*"
        return
    fi
    local code=""
    case "$color" in
        red)    code="\033[0;31m" ;;
        green)  code="\033[0;32m" ;;
        yellow) code="\033[0;33m" ;;
        cyan)   code="\033[0;36m" ;;
        gray)   code="\033[0;90m" ;;
        white)  code="\033[0;37m" ;;
        *)      code="" ;;
    esac
    if [[ -n "$code" ]]; then
        echo -e "${code}$*\033[0m"
    else
        echo "$*"
    fi
}

# Helper: output line (respects email mode)
output_line() {
    local color="${1:-white}"
    shift
    if $EMAIL_OUTPUT; then
        echo "$*"
    else
        color_echo "$color" "$*"
    fi
}

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Load credentials from config if not provided
if [[ -z "$USERNAME" ]]; then
    stored_user="$(get_password "ezpass-monitor/username" 2>/dev/null)" || true
    if [[ -n "$stored_user" ]]; then
        USERNAME="$stored_user"
    fi
fi

if [[ -z "$PASSWORD" ]]; then
    stored_pass="$(get_password "ezpass-monitor/password" 2>/dev/null)" || true
    if [[ -n "$stored_pass" ]]; then
        PASSWORD="$stored_pass"
    fi
fi

# Save config if requested
if $SAVE_CONFIG; then
    if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
        color_echo red "Error: Please provide --username and --password to save config"
        exit 1
    fi

    store_password "ezpass-monitor/username" "$USERNAME"
    store_password "ezpass-monitor/password" "$PASSWORD"

    color_echo green "[OK] Credentials saved securely (backend: $(get_backend_name))"
    exit 0
fi

# Validate credentials
if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    color_echo red "Error: Username and password required."
    echo ""
    color_echo cyan "First time setup:"
    echo "  ./setup.sh"
    echo ""
    color_echo cyan "Or provide credentials manually:"
    echo "  ./check-tolls.sh --username 'user' --password 'pass' --save-config"
    exit 1
fi

# Determine month and year
NOW_YEAR="$(date +%Y)"
NOW_MONTH="$(date +%-m)"
NOW_DAY="$(date +%-d)"

if [[ -z "$YEAR" ]]; then YEAR="$NOW_YEAR"; fi
if [[ -z "$MONTH" ]]; then MONTH="$NOW_MONTH"; fi

# Convert to 0-indexed month for API (0=January, 11=December)
MONTH_INDEX=$((MONTH - 1))

if [[ -n "$VERIFY_DISCOUNT" ]]; then
    if ! echo "$VERIFY_DISCOUNT" | grep -qE '^[0-9]+(\.[0-9]{1,2})?$'; then
        color_echo red "Error: --verify-discount requires a numeric amount (e.g., 24.80)"
        exit 1
    fi
fi

vlog "Target period: ${MONTH}/${YEAR} (API month index: ${MONTH_INDEX})"
vlog "Current date: $(date '+%Y-%m-%d %H:%M:%S')"

# Check session cache age
use_cached_session=false

if [[ -f "$COOKIE_FILE" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        file_mtime=$(stat -f %m "$COOKIE_FILE")
    else
        file_mtime=$(stat -c %Y "$COOKIE_FILE")
    fi
    now_epoch=$(date +%s)
    cache_age=$((now_epoch - file_mtime))

    if [[ $cache_age -lt $SESSION_MAX_AGE ]]; then
        use_cached_session=true
        vlog "Using cached cookies (age: ${cache_age}s)"
        color_echo green "Using cached session..."
    else
        vlog "Cached session too old (${cache_age}s), will re-login"
    fi
fi

# Login if needed
if ! $use_cached_session; then
    color_echo cyan "Getting login page..."

    LOGIN_PAGE_URL="${BASE_URL}/EZPass/Login.do"

    login_page=$(curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" \
        -o - -w "\n%{http_code}" \
        "$LOGIN_PAGE_URL") || {
        color_echo red "Error: Failed to get login page"
        exit 2
    }

    http_code="${login_page##*$'\n'}"
    login_html="${login_page%$'\n'*}"

    vlog "Login page status: ${http_code}"
    vlog "Login page content length: ${#login_html}"

    # Check if service is unavailable
    if echo "$login_html" | grep -qi 'currently unavailable\|We'\''re Sorry'; then
        echo ""
        color_echo red "ERROR: Maine EZPass service is currently unavailable"
        color_echo yellow "The website shows: 'The online Maine Customer Service Center is currently unavailable.'"
        color_echo yellow "This is likely due to maintenance or technical issues on their end."
        color_echo yellow "Please try again later (in 30 minutes to a few hours)."
        echo ""
        exit 2
    fi

    # Extract CSRF token
    token_name=$(echo "$login_html" | grep -oP 'name="(token_[^"]+)"' | head -1 | sed 's/name="//;s/"//')
    token_value=$(echo "$login_html" | grep -oP 'name="token_[^"]+"\s+value="([^"]+)"' | head -1 | sed 's/.*value="//;s/"//')

    if [[ -z "$token_name" || -z "$token_value" ]]; then
        color_echo red "Error: Could not find CSRF token on login page"
        if $VERBOSE; then
            echo "$login_html" > login-page-debug.html
            vlog "Login page saved to: login-page-debug.html"
        fi
        exit 2
    fi

    color_echo green "Found CSRF token: ${token_name}"
    vlog "CSRF token value: ${token_value:0:20}..."

    color_echo cyan "Logging in as ${USERNAME}..."

    LOGIN_URL="${BASE_URL}/EZPass/ProcessLogin.do"

    login_response=$(curl -s -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
        -o - -w "\n%{http_code}" \
        -X POST "$LOGIN_URL" \
        --data-urlencode "${token_name}=${token_value}" \
        --data-urlencode "username=${USERNAME}" \
        --data-urlencode "password=${PASSWORD}" \
        --data-urlencode "cmdSubmit=Login") || {
        color_echo red "Error: Login failed"
        exit 2
    }

    login_http="${login_response##*$'\n'}"
    login_body="${login_response%$'\n'*}"

    if echo "$login_body" | grep -q 'ProcessLogout\.do'; then
        color_echo green "[OK] Login successful!"
        color_echo green "Session cached for 10 minutes"
        vlog "Login response status: ${login_http}"

    elif echo "$login_body" | grep -q 'Account Already Logged In'; then
        echo ""
        color_echo yellow "WARNING: Account is already logged in from another session."
        color_echo yellow "The EZPass system only allows one active session at a time."
        echo ""
        color_echo cyan "Waiting 90 seconds for the session to timeout, then retrying..."
        sleep 90

        # Retry login with fresh token
        color_echo cyan "Retrying login..."

        login_page=$(curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" -o - "$LOGIN_PAGE_URL")
        token_name=$(echo "$login_page" | grep -oP 'name="(token_[^"]+)"' | head -1 | sed 's/name="//;s/"//')
        token_value=$(echo "$login_page" | grep -oP 'name="token_[^"]+"\s+value="([^"]+)"' | head -1 | sed 's/.*value="//;s/"//')

        if [[ -n "$token_name" && -n "$token_value" ]]; then
            login_response=$(curl -s -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
                -o - -w "\n%{http_code}" \
                -X POST "$LOGIN_URL" \
                --data-urlencode "${token_name}=${token_value}" \
                --data-urlencode "username=${USERNAME}" \
                --data-urlencode "password=${PASSWORD}" \
                --data-urlencode "cmdSubmit=Login")

            login_body="${login_response%$'\n'*}"

            if echo "$login_body" | grep -q 'ProcessLogout\.do'; then
                color_echo green "[OK] Login successful on retry!"
            else
                color_echo red "Error: Login still failed. Please wait 5 minutes and try again."
                exit 2
            fi
        else
            color_echo red "Error: Retry failed - could not get CSRF token"
            exit 2
        fi
    else
        color_echo red "Error: Login failed - invalid credentials or unexpected response"
        exit 2
    fi
fi

# Fetch toll data as CSV
color_echo cyan "Fetching toll data for ${MONTH}/${YEAR}..."

CSV_URL="${BASE_URL}/EZPass/DownloadPostedTolls.do?year=${YEAR}&month=${MONTH_INDEX}"
vlog "CSV URL: ${CSV_URL}"

csv_data=$(curl -s -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
    -H "Referer: ${BASE_URL}/EZPass/Summary.do" \
    -H "Sec-Fetch-Site: same-origin" \
    "$CSV_URL") || {
    color_echo red "Error: Failed to fetch toll data"
    exit 2
}

vlog "CSV content length: ${#csv_data} bytes"

# Validate CSV response
if echo "$csv_data" | head -1 | grep -qi '<html\|<!DOCTYPE'; then
    color_echo red "Error: Received HTML instead of CSV data (possible login failure)"
    if $VERBOSE; then
        echo "$csv_data" > csv-debug.html
        vlog "HTML response saved to: csv-debug.html"
    fi
    exit 2
fi

if [[ ${#csv_data} -lt 50 ]]; then
    color_echo red "Error: CSV response too short (${#csv_data} bytes) - no data returned"
    exit 2
fi

if ! echo "$csv_data" | head -1 | grep -qi 'Transaction Date'; then
    color_echo red "Error: CSV response missing expected headers"
    if $VERBOSE; then
        vlog "First line of response: $(echo "$csv_data" | head -1)"
    fi
    exit 2
fi

# Save CSV to file if requested
if $DOWNLOAD_FILE; then
    csv_filename="toll-data-${MONTH}-${YEAR}.csv"
    echo "$csv_data" > "$csv_filename"
    color_echo green "[OK] CSV data saved to: ${csv_filename}"
fi

vlog "Parsing CSV data..."

# Parse CSV data using python3 csv module for proper RFC 4180 handling
# (awk -F',' cannot handle quoted fields containing commas, e.g. "Exit 44, Scarborough")
# CSV columns: "Posting Date","Tag/Vehicle Reg.","Transaction Date","Transaction Time",
#              "Facility","Entry/Barrier Plaza","Exit Plaza","Toll","Discount Eligible?"

parse_result=$(echo "$csv_data" | python3 -c '
import csv, sys, re

reader = csv.DictReader(sys.stdin)
total_tolls = 0
discount_eligible = 0
total_amount = 0.0

for row in reader:
    trans_date = (row.get("Transaction Date") or "").strip()
    amount_str = (row.get("Toll") or "").strip()
    if not trans_date or not amount_str:
        continue

    total_tolls += 1
    posting_date = (row.get("Posting Date") or "").strip()
    trans_time = (row.get("Transaction Time") or "").strip()
    facility = (row.get("Facility") or "").strip()
    entry = (row.get("Entry/Barrier Plaza") or "").strip()
    exit_plaza = (row.get("Exit Plaza") or "").strip()
    eligible = (row.get("Discount Eligible?") or "").strip()

    # Parse amount - handle "$0.80" and "$.80" formats
    amt = re.sub(r"^\$", "", amount_str)
    if amt.startswith("."):
        amt = "0" + amt
    try:
        amount = float(amt)
    except ValueError:
        amount = 0.0

    if eligible == "Yes":
        discount_eligible += 1
        total_amount += amount

    print("DETAIL|%s|%s %s|%s|%s|%s|%.2f|%s|%s" % (
        posting_date, trans_date, trans_time, facility, entry, exit_plaza,
        amount, amount_str, eligible))

print("SUMMARY|%d|%d|%.2f" % (total_tolls, discount_eligible, total_amount))
')

# Extract summary line
summary_line=$(echo "$parse_result" | grep "^SUMMARY|" | tail -1)
total_tolls=$(echo "$summary_line" | cut -d'|' -f2)
discount_eligible=$(echo "$summary_line" | cut -d'|' -f3)
total_amount=$(echo "$summary_line" | cut -d'|' -f4)

# Default to 0 if empty
total_tolls=${total_tolls:-0}
discount_eligible=${discount_eligible:-0}
total_amount=${total_amount:-0.00}

vlog "Parsing complete: ${total_tolls} total, ${discount_eligible} eligible, Total amount: \$${total_amount}"

# Extract detail lines
detail_lines=$(echo "$parse_result" | grep "^DETAIL|" || true)

# Helper: determine discount tier
get_tier() {
    local count=$1
    if [[ $count -ge 40 ]]; then
        echo "Gold"
    elif [[ $count -ge 30 ]]; then
        echo "Bronze"
    else
        echo "None"
    fi
}

get_tier_discount() {
    local tier=$1
    case "$tier" in
        Gold) echo "40" ;;
        Bronze) echo "20" ;;
        *) echo "0" ;;
    esac
}

get_tier_message() {
    local tier=$1
    case "$tier" in
        Gold) echo "40% discount - Maximum savings!" ;;
        Bronze) echo "20% discount" ;;
        *) echo "No discount" ;;
    esac
}

# Helper: days in month
days_in_month() {
    local y=$1 m=$2
    date -d "${y}-${m}-01 +1 month -1 day" +%d 2>/dev/null || \
        python3 -c "import calendar; print(calendar.monthrange(${y},${m})[1])" 2>/dev/null || \
        echo 30
}

# SMS Format Output
if $SMS_FORMAT; then
    estimated_total=$discount_eligible

    if $ESTIMATE && [[ "$YEAR" -eq "$NOW_YEAR" ]] && [[ "$MONTH" -eq "$NOW_MONTH" ]]; then
        dim=$(days_in_month "$YEAR" "$MONTH")
        if [[ $NOW_DAY -gt 0 ]]; then
            # Use awk for floating point arithmetic
            estimated_total=$(awk "BEGIN { printf \"%.0f\", ($discount_eligible / $NOW_DAY) * $dim }")
        fi
    fi

    # Determine tier
    toll_count=$estimated_total
    tier=$(get_tier "$toll_count")

    # Generate progress bar
    progress_bar() {
        local current=$1 target=${2:-40} width=${3:-8}
        local filled empty
        filled=$(awk "BEGIN { v = int(($current / $target) * $width); if (v > $width) v = $width; print v }")
        empty=$((width - filled))
        printf "[%s%s]" "$(printf '=%.0s' $(seq 1 "$filled" 2>/dev/null) 2>/dev/null)" "$(printf -- '-%.0s' $(seq 1 "$empty" 2>/dev/null) 2>/dev/null)"
    }

    bar=$(progress_bar "$toll_count" 40 8)

    if [[ "$tier" == "Gold" ]]; then
        savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.40 }")
        echo "EZPass: ${bar} ${toll_count}/40"
        echo "Gold 40% | -\$${savings}/mo"
    elif [[ "$tier" == "Bronze" ]]; then
        needed=$((40 - toll_count))
        additional_savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.20 }")
        echo "EZPass: ${bar} ${toll_count}/40"
        echo "Bronze 20% | ${needed}→Gold +\$${additional_savings}"
    else
        potential_savings=$(awk "BEGIN { printf \"%.2f\", $total_amount * 0.40 }")
        if $ESTIMATE; then
            est_display="Est ${estimated_total}"
        else
            est_display="${toll_count}"
        fi
        echo "EZPass: ${bar} ${toll_count}/40"
        echo "${est_display} → Gold -\$${potential_savings}"
    fi

    # Exit code based on tier
    case "$tier" in
        Gold)   exit 1 ;;
        Bronze) exit 2 ;;
        *)      exit 3 ;;
    esac
fi

# Verify Discount Mode
if [[ -n "$VERIFY_DISCOUNT" ]]; then
    tier=$(get_tier "$discount_eligible")
    discount_pct_num=$(get_tier_discount "$tier")

    if [[ $discount_pct_num -gt 0 ]]; then
        expected_discount=$(awk "BEGIN { printf \"%.2f\", $total_amount * ($discount_pct_num / 100.0) }")
    else
        expected_discount="0.00"
    fi

    provided_discount="$VERIFY_DISCOUNT"
    abs_difference=$(awk "BEGIN { v = $provided_discount - $expected_discount; printf \"%.2f\", (v < 0) ? -v : v }")
    match=$(awk "BEGIN { v = $provided_discount - $expected_discount; print ((v < 0 ? -v : v) < 0.015) ? 1 : 0 }")

    output_line cyan ""
    output_line cyan "$(printf '=%.0s' {1..60})"
    output_line white "DISCOUNT VERIFICATION FOR ${MONTH}/${YEAR}"
    output_line cyan "$(printf '=%.0s' {1..60})"
    output_line white ""
    output_line white "Discount-eligible tolls:  ${discount_eligible}"
    output_line white "Discount tier:            ${tier} (${discount_pct_num}%)"
    output_line white "Eligible toll total:      \$${total_amount}"
    output_line white ""
    output_line cyan  "$(printf -- '-%.0s' {1..60})"
    output_line white "Expected discount:        \$${expected_discount}"
    output_line white "EZPass stated discount:   \$${provided_discount}"
    output_line cyan  "$(printf -- '-%.0s' {1..60})"

    if [[ "$match" -eq 1 ]]; then
        output_line green ""
        output_line green ">> MATCH: Discount amount verified successfully."
        output_line green ""
        exit 0
    else
        difference=$(awk "BEGIN { printf \"%.2f\", $provided_discount - $expected_discount }")
        if [[ $(awk "BEGIN { print ($difference > 0) ? 1 : 0 }") -eq 1 ]]; then
            direction="EZPass charged MORE than expected by"
        else
            direction="EZPass charged LESS than expected by"
        fi
        output_line red ""
        output_line red ">> MISMATCH: ${direction} \$${abs_difference}"
        output_line yellow "   Review toll details with --verbose for discrepancies."
        output_line red ""
        exit 4
    fi
fi

# Standard report output
output_line cyan ""
output_line cyan "$(printf '=%.0s' {1..60})"
output_line white "TOLL REPORT FOR ${MONTH}/${YEAR}"
output_line cyan "$(printf '=%.0s' {1..60})"
output_line white "Total tolls posted: ${total_tolls}"
output_line white "Discount-eligible tolls: ${discount_eligible}"
output_line cyan "$(printf '=%.0s' {1..60})"

# Estimate if requested and checking current month
estimated_total=$discount_eligible

if $ESTIMATE && [[ "$YEAR" -eq "$NOW_YEAR" ]] && [[ "$MONTH" -eq "$NOW_MONTH" ]]; then
    dim=$(days_in_month "$YEAR" "$MONTH")

    if [[ $NOW_DAY -gt 0 ]]; then
        daily_avg=$(awk "BEGIN { printf \"%.2f\", $discount_eligible / $NOW_DAY }")
        estimated_total_raw=$(awk "BEGIN { printf \"%.1f\", ($discount_eligible / $NOW_DAY) * $dim }")
        estimated_total_int=$(awk "BEGIN { printf \"%.0f\", ($discount_eligible / $NOW_DAY) * $dim }")
        estimated_total=$estimated_total_int

        vlog "Estimation: Day ${NOW_DAY} of ${dim} | Daily avg: ${daily_avg} | Projected: ${estimated_total_raw}"

        output_line white ""
        output_line white "Current day: ${NOW_DAY} of ${dim}"
        output_line white "Estimated month-end discount-eligible tolls: ${estimated_total_raw}"
        output_line cyan "$(printf '=%.0s' {1..60})"

        tier=$(get_tier "$estimated_total")
        tier_msg=$(get_tier_message "$tier")

        case "$tier" in
            Gold)   tier_color="green" ;;
            Bronze) tier_color="yellow" ;;
            *)      tier_color="red" ;;
        esac

        output_line "$tier_color" ""
        output_line "$tier_color" ">> Projected Discount Tier: ${tier}"
        output_line "$tier_color" "   ${tier_msg}"
        output_line "$tier_color" "   Estimated: ${estimated_total_raw} tolls"

        # Show what's needed for next tier
        if [[ $(awk "BEGIN { print ($estimated_total_raw < 30) ? 1 : 0 }") -eq 1 ]]; then
            needed=$(awk "BEGIN { printf \"%.1f\", 30 - $estimated_total_raw }")
            output_line cyan ""
            output_line cyan "TIP: Need ${needed} more tolls for 20% discount"
        elif [[ $(awk "BEGIN { print ($estimated_total_raw < 40) ? 1 : 0 }") -eq 1 ]]; then
            needed=$(awk "BEGIN { printf \"%.1f\", 40 - $estimated_total_raw }")
            output_line cyan ""
            output_line cyan "TIP: Need ${needed} more tolls for 40% discount"
            drop_by=$(awk "BEGIN { printf \"%.1f\", $estimated_total_raw - 29 }")
            output_line yellow "WARNING: Or reduce by ${drop_by} tolls to drop to no discount tier"
        fi
    fi
else
    # For completed months
    tier=$(get_tier "$discount_eligible")
    tier_msg=$(get_tier_message "$tier")

    case "$tier" in
        Gold)   tier_color="green" ;;
        Bronze) tier_color="yellow" ;;
        *)      tier_color="red" ;;
    esac

    output_line "$tier_color" ""
    output_line "$tier_color" ">> Discount Tier: ${tier}"
    output_line "$tier_color" "   ${tier_msg}"
    output_line "$tier_color" "   Total: ${discount_eligible} tolls"
fi

# Show detailed toll information
if [[ -n "$detail_lines" ]]; then
    output_line cyan ""
    output_line cyan "$(printf '=%.0s' {1..70})"
    output_line white "TOLL TRANSACTIONS THIS MONTH"
    output_line cyan "$(printf '=%.0s' {1..70})"

    # Determine projected tier for discount calculation
    if $ESTIMATE && [[ $estimated_total -ge 0 ]]; then
        proj_tier=$(get_tier "$estimated_total")
    else
        proj_tier=$(get_tier "$discount_eligible")
    fi

    discount_pct=0
    case "$proj_tier" in
        Gold)   discount_pct=40 ;;
        Bronze) discount_pct=20 ;;
    esac

    i=1
    total_savings="0.00"

    while IFS='|' read -r _ posted_date trans_datetime facility entry exit_plaza amount amount_str eligible; do
        discounted_amount=$amount
        savings="0.00"

        if [[ "$eligible" == "Yes" && $discount_pct -gt 0 ]]; then
            discounted_amount=$(awk "BEGIN { printf \"%.2f\", $amount * (1 - $discount_pct / 100.0) }")
            savings=$(awk "BEGIN { printf \"%.2f\", $amount - $discounted_amount }")
            total_savings=$(awk "BEGIN { printf \"%.2f\", $total_savings + $savings }")
        fi

        output_line white ""
        output_line white "${i}. ${trans_datetime} - ${facility}:"
        output_line white "   From ${entry} to ${exit_plaza}"

        if [[ "$eligible" == "Yes" && $discount_pct -gt 0 ]]; then
            output_line white "   Toll: \$${amount} -> \$${discounted_amount} (save \$${savings} with ${discount_pct}% discount)"
        elif [[ "$eligible" == "Yes" ]]; then
            output_line white "   Toll: \$${amount} [Eligible - no discount yet]"
        else
            output_line white "   Toll: \$${amount} [Not Eligible]"
        fi

        ((i++))
    done <<< "$detail_lines"

    if [[ $(awk "BEGIN { print ($total_savings > 0) ? 1 : 0 }") -eq 1 ]]; then
        output_line green ""
        output_line green "Total Savings This Month: \$${total_savings}"
    fi

    output_line cyan ""
    output_line cyan "$(printf '=%.0s' {1..70})"
elif [[ $total_tolls -eq 0 ]]; then
    output_line gray ""
    output_line gray "No tolls posted this month yet."
    output_line gray ""
fi

# Determine exit code
if $ESTIMATE && [[ $estimated_total -ge 0 ]]; then
    final_count=$estimated_total
else
    final_count=$discount_eligible
fi

if [[ $final_count -lt 30 ]]; then
    exit_code=3
elif [[ $final_count -lt 40 ]]; then
    exit_code=2
else
    exit_code=1
fi

vlog "Final count: ${final_count} | Exit code: ${exit_code} (3=None, 2=Bronze, 1=Gold)"

exit "$exit_code"
