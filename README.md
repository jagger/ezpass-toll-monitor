# Maine EZPass Toll Monitor

Automated PowerShell tool to monitor your Maine EZPass toll usage and track discount eligibility.

## Disclaimer

**This is an unofficial, independent project and is not affiliated with, endorsed by, or sponsored by the Maine Turnpike Authority (MTA) or E-ZPass.**

This tool:
- Uses publicly available data from your personal EZPass account
- Is provided as-is for personal use only
- Is not an official Maine Turnpike Authority application
- Should be used in accordance with the EZPass Terms of Service

Maine Turnpike Authority, E-ZPass, and related trademarks are property of their respective owners. This project is an independent utility created to help users monitor their own toll usage for personal financial planning purposes.

**Users are solely responsible for:**
- The security of their credentials
- Compliance with EZPass Terms of Service
- Any actions taken based on the information provided by this tool

## Discount Tiers

- **0-29 tolls/month**: No discount
- **30-39 tolls/month**: 20% discount (Bronze tier)
- **40+ tolls/month**: 40% discount (Gold tier - maximum savings!)

## Features

- **Session Caching**: Automatically caches login sessions for 10 minutes to avoid "account already logged in" errors
- **CSV Data Download**: Fetches toll data via clean CSV API instead of HTML scraping
- **Service Status Detection**: Automatically detects when EZPass service is unavailable
- **Discount Calculations**: Shows actual discounted toll amounts based on your projected tier
- **Savings Tracking**: Calculates total monthly savings with current discount tier
- **Email Notifications**: Automated email alerts with error handling
- **Toast Notifications**: Windows 10/11 native notifications
- **Verbose Logging**: Detailed debugging output with `-Verbose` flag
- **Data Export**: Save toll CSV files with `-DownloadFile` flag

## Quick Start

### 1. Initial Setup

```powershell
.\setup.ps1
```

This will:
- Prompt for your EZPass credentials (encrypted with Windows DPAPI)
- Optionally configure email notifications
- Save everything to `~\.ezpass\config.xml` (secure, encrypted storage)
- Test the connection
- Verify everything works

### 2. Check Current Month

```powershell
.\check-tolls.ps1 -Estimate
```

Output example:
```
============================================================
TOLL REPORT FOR 1/2026
============================================================
Total tolls posted: 8
Discount-eligible tolls: 8
============================================================

Current day: 4 of 31
Estimated month-end discount-eligible tolls: 62.0
============================================================

>> Projected Discount Tier: Gold
   40% discount - Maximum savings!
   Estimated: 62.0 tolls

======================================================================
TOLL TRANSACTIONS THIS MONTH
======================================================================

1. 01/03/2026 15:23:46 - MeTA:
   From Crabapple Cove (77) to Derry (181)
   Toll: $0.80 -> $0.48 (save $0.32 with 40% discount)

Total Savings This Month: $2.46
======================================================================
```

### 3. Run Email Notifications (If Configured)

If you configured email during setup:
```powershell
.\notify-email.ps1
```

To reconfigure email settings, run setup again:
```powershell
.\setup.ps1
```

## Command Reference

### check-tolls.ps1

Main script that fetches and analyzes toll data.

**Parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Username` | EZPass username | `-Username "jagger"` |
| `-Password` | EZPass password | `-Password "yourpassword"` |
| `-Month` | Month to check (1-12) | `-Month 12` |
| `-Year` | Year to check | `-Year 2025` |
| `-Estimate` | Project month-end totals | `-Estimate` |
| `-Verbose` | Show detailed debug output | `-Verbose` |
| `-DownloadFile` | Save CSV to file | `-DownloadFile` |
| `-SaveConfig` | Save credentials to secure config | `-SaveConfig` |
| `-EmailOutput` | Format output for email capture | `-EmailOutput` |

**Examples:**

```powershell
# Quick check with estimation
.\check-tolls.ps1 -Estimate

# Check specific month
.\check-tolls.ps1 -Month 12 -Year 2025

# Verbose output with CSV download
.\check-tolls.ps1 -Estimate -Verbose -DownloadFile

# Save credentials for first time
.\check-tolls.ps1 -Username "jagger" -Password "yourpass" -SaveConfig

# Check last month
$lastMonth = (Get-Date).AddMonths(-1)
.\check-tolls.ps1 -Month $lastMonth.Month -Year $lastMonth.Year
```

**Exit Codes:**

- `1` - Gold tier (40+ tolls)
- `2` - Bronze tier (30-39 tolls) OR login/service error
- `3` - No discount tier (0-29 tolls)

### notify-email.ps1

Wrapper that runs check-tolls.ps1 and sends results via email.

```powershell
.\notify-email.ps1
```

Reads email configuration from `~\.ezpass\config.xml` (created by `setup.ps1`).

**Email Subjects:**
- Service down: "EZPass Monitor - Service Currently Unavailable"
- Error: "EZPass Monitor Error - Failed to retrieve toll data"
- No discount: "EZPass Alert: No Discount - Potential $X.XX savings with Gold"
- Bronze: "EZPass Alert: Bronze (20%) - $X.XX more with Gold"
- Gold: "EZPass Alert: Gold (40%) - Saving $X.XX this month!"

### notify-toast.ps1

Shows Windows toast notifications with toll status.

```powershell
.\notify-toast.ps1

# Only notify for specific tiers
.\notify-toast.ps1 -OnlyAlertOnTiers "Bronze,Gold"
```

## Session Caching

The tool automatically caches your login session for 10 minutes to prevent "account already logged in" errors when running multiple times.

**Cache location:** `~\.ezpass\cookies.xml`

**How it works:**
- First run: Logs in and saves session cookies
- Subsequent runs (within 10 min): Reuses cached session, no login needed
- After 10 min: Cache expires, performs fresh login

**Verbose output:**
```powershell
.\check-tolls.ps1 -Verbose -Estimate

# Shows:
[VERBOSE] Loaded 1 cached cookies (age: 45.2s)
Using cached session...
Fetching toll data for 1/2026...
```

## Error Handling

### Service Unavailable

When the EZPass website is down for maintenance:

```
ERROR: Maine EZPass service is currently unavailable
The website shows: 'The online Maine Customer Service Center is currently unavailable.'
This is likely due to maintenance or technical issues on their end.
Please try again later (in 30 minutes to a few hours).
```

Email subject: "EZPass Monitor - Service Currently Unavailable"

### Login Conflicts

If your account is already logged in elsewhere:

```
WARNING: Account is already logged in from another session.
The EZPass system only allows one active session at a time.

Waiting 90 seconds for the session to timeout, then retrying...
```

The script automatically waits and retries. Future runs within 10 minutes use cached session to avoid this.

## Automation with Task Scheduler

### Weekly Email Reports

1. Open Task Scheduler (`taskschd.msc`)
2. Create Basic Task:
   - **Name:** EZPass Weekly Report
   - **Trigger:** Weekly, Fridays at 6:00 PM
   - **Action:** Start a program
   - **Program:** `powershell.exe`
   - **Arguments:** `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\jagge\Documents\tolls\prod\notify-email.ps1"`
   - **Start in:** `C:\Users\jagge\Documents\tolls\prod`

### Daily Checks (Advanced)

For daily monitoring, use Task Scheduler with conditional email:

```powershell
# Script: daily-check.ps1
cd C:\Users\jagge\Documents\tolls\prod

$output = .\check-tolls.ps1 -Estimate -EmailOutput
$exitCode = $LASTEXITCODE

# Only send email if below Gold tier or error occurred
if ($exitCode -ne 1) {
    .\notify-email.ps1
}
```

## Troubleshooting

### Execution Policy Error

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run with bypass:
```powershell
powershell -ExecutionPolicy Bypass -File .\check-tolls.ps1 -Estimate
```

### Login Fails

1. Verify credentials at https://ezpassmaineturnpike.com
2. Check if session cache is corrupted: Delete `~\.ezpass\cookies.xml`
3. Wait 5 minutes if "already logged in" error persists
4. Run `.\setup.ps1` to reconfigure credentials

### No Toll Data

- Ensure you have tolls for the specified month
- Try with `-Verbose` to see detailed debug output
- Run `.\setup.ps1` to verify credentials are configured correctly

### Email Not Sending

**Gmail users:**
1. Enable 2-Factor Authentication
2. Create App Password at https://myaccount.google.com/apppasswords
3. Use the 16-character app password (not your regular password)

**Other providers:**
- Outlook/Hotmail: `smtp.office365.com:587`
- Yahoo: `smtp.mail.yahoo.com:587` (requires app password)

Run `.\setup.ps1` and configure email settings.

## Configuration Files

### ~\.ezpass\config.xml

Secure configuration file encrypted with Windows Data Protection API (DPAPI).

**Location:** `C:\Users\[YourUsername]\.ezpass\config.xml`

**Structure:**
```powershell
@{
    EZPass = @{
        Username = "your_ezpass_username"
        Password = <SecureString encrypted by DPAPI>
    }
    Email = @{
        SmtpServer = "smtp.gmail.com"
        Port = 587
        From = "your-email@gmail.com"
        To = "your-email@gmail.com"
        Username = "your-email@gmail.com"
        Password = <SecureString encrypted by DPAPI>
        UseSsl = $true
        OnlyAlertOnTiers = ""
    }
}
```

**Security Note:** Credentials are encrypted using Windows DPAPI and can only be decrypted by your Windows user account. This file is automatically created by `.\setup.ps1`.

## Advanced Usage

### Download and Inspect CSV Data

```powershell
.\check-tolls.ps1 -DownloadFile -Verbose

# Creates: toll-data-MM-YYYY.csv
```

CSV format:
```csv
"Posting Date","Tag/Vehicle Reg.","Transaction Date","Transaction Time","Facility","Entry/Barrier Plaza","Exit Plaza","Toll","Discount Eligible?"
"01/03/2026","012345678901","01/03/2026","15:23:46","MeTA","Crabapple Cove (77)","Derry (181)","$.80","Yes"
```

### Custom Notification Scripts

Create your own notification wrapper:

```powershell
# my-custom-alert.ps1
$result = .\check-tolls.ps1 -Estimate -EmailOutput
$exitCode = $LASTEXITCODE

if ($exitCode -eq 3) {
    # Custom logic for no discount tier
    Write-Host "WARNING: Below 30 tolls!" -ForegroundColor Red
    # Send SMS, webhook, etc.
}
```

## How It Works

1. **Login**: Connects to EZPass Maine website with your credentials
2. **Session**: Saves session cookies to avoid repeated logins
3. **Fetch**: Downloads toll data as CSV via API
4. **Parse**: Processes CSV to extract toll transactions 
5. **Analyze**: Counts discount-eligible tolls and calculates tier
6. **Estimate**: Projects month-end totals based on daily average
7. **Display**: Shows detailed report with discounted amounts
8. **Notify**: Sends email/toast notification if configured

## Files

**Scripts:**
- `check-tolls.ps1` - Main toll checking script
- `notify-email.ps1` - Email notification wrapper
- `notify-toast.ps1` - Toast notification wrapper
- `setup.ps1` - Interactive setup (EZPass credentials + optional email)

**Configuration:**
- `~\.ezpass\config.xml` - Secure encrypted configuration (created by setup)
- `~\.ezpass\cookies.xml` - Session cache (auto-generated, 10-min TTL)

**Documentation:**
- `README.md` - This file
- `QUICK-START.md` - Quick start guide
- `NOTIFICATIONS-GUIDE.md` - Notification setup guide


## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
