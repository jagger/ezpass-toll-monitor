# Maine EZPass Toll Monitor

Automated tool to monitor your Maine EZPass toll usage and track discount eligibility.

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

## Platform Support

| Platform | Scripts | Status |
|----------|---------|--------|
| **Windows** | PowerShell (`.ps1`) | `windows/` directory |
| **Linux** | Bash (`.sh`) | `linux/` directory |
| **macOS** | Bash (`.sh`) | `linux/` directory |

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
- **SMS Notifications**: Compact text message alerts via email-to-SMS gateways
- **Desktop Notifications**: Windows toast notifications or Linux `notify-send` / macOS `osascript`
- **Verbose Logging**: Detailed debugging output with `--verbose` flag
- **Data Export**: Save toll CSV files with `--download` flag

## Quick Start

### Windows

#### 1. Initial Setup

```powershell
windows\setup.ps1
```

This will:
- Prompt for your EZPass credentials (encrypted with Windows DPAPI)
- Optionally configure email notifications
- Optionally configure SMS notifications (requires email setup)
- Save everything to `~\.ezpass\config.xml` (secure, encrypted storage)
- Test the connection
- Verify everything works

#### 2. Check Current Month

```powershell
windows\check-tolls.ps1 -Estimate
```

#### 3. Run Notifications (If Configured)

```powershell
windows\notify-email.ps1    # Detailed email report
windows\notify-sms.ps1      # Compact SMS alert
windows\notify-toast.ps1    # Windows desktop notification
```

### Linux / macOS

#### 1. Initial Setup

```bash
chmod +x linux/*.sh linux/lib/*.sh linux/check-tolls
linux/setup.sh
```

This will:
- Prompt for your EZPass credentials
- Store credentials securely (macOS Keychain, `pass`, or OpenSSL encrypted file)
- Optionally configure email notifications
- Optionally configure SMS notifications (requires email setup)
- Save non-sensitive settings to `~/.ezpass/config.json`
- Test the connection

#### 2. Check Current Month

```bash
linux/check-tolls.sh --estimate
```

#### 3. Run Notifications (If Configured)

```bash
linux/notify-email.sh      # Detailed email report
linux/notify-sms.sh        # Compact SMS alert
linux/notify-desktop.sh    # Desktop notification (notify-send / osascript)
```

### Output Example

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

### SMS Format Example

```
EZPass: [█████░░░] 35/40
Bronze 20% | 5→Gold +$6.20
```

See **[NOTIFICATIONS.md](NOTIFICATIONS.md)** for complete setup and carrier information.

## Command Reference

### Windows: check-tolls.ps1

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
| `-SmsFormat` | Compact SMS-friendly output format | `-SmsFormat` |
| `-VerifyDiscount` | Verify EZPass discount amount | `-VerifyDiscount 24.80 -Month 1 -Year 2026` |

**Examples:**

```powershell
# Quick check with estimation
windows\check-tolls.ps1 -Estimate

# Check specific month
windows\check-tolls.ps1 -Month 12 -Year 2025

# Verbose output with CSV download
windows\check-tolls.ps1 -Estimate -Verbose -DownloadFile

# Save credentials for first time
windows\check-tolls.ps1 -Username "jagger" -Password "yourpass" -SaveConfig

# Verify EZPass discount statement
windows\check-tolls.ps1 -VerifyDiscount 24.80 -Month 1 -Year 2026
```

### Linux/macOS: check-tolls.sh

**Options:**

| Option | Description | Example |
|--------|-------------|---------|
| `--username` | EZPass username | `--username "jagger"` |
| `--password` | EZPass password | `--password "yourpassword"` |
| `--month` | Month to check (1-12) | `--month 12` |
| `--year` | Year to check | `--year 2025` |
| `--estimate` | Project month-end totals | `--estimate` |
| `--verbose` | Show detailed debug output | `--verbose` |
| `--download` | Save CSV to file | `--download` |
| `--save-config` | Save credentials to secure config | `--save-config` |
| `--email-output` | Format output for email capture | `--email-output` |
| `--sms-format` | Compact SMS-friendly output format | `--sms-format` |
| `--verify-discount` | Verify EZPass discount amount | `--verify-discount 24.80 --month 1 --year 2026` |

**Examples:**

```bash
# Quick check with estimation
linux/check-tolls.sh --estimate

# Check specific month
linux/check-tolls.sh --month 12 --year 2025

# Verbose output with CSV download
linux/check-tolls.sh --estimate --verbose --download

# Save credentials for first time
linux/check-tolls.sh --username "jagger" --password "yourpass" --save-config

# Verify EZPass discount statement
linux/check-tolls.sh --verify-discount 24.80 --month 1 --year 2026
```

**Exit Codes (both platforms):**

- `0` - Discount verified (match) when using `--verify-discount`
- `1` - Gold tier (40+ tolls)
- `2` - Bronze tier (30-39 tolls) OR login/service error
- `3` - No discount tier (0-29 tolls)
- `4` - Discount mismatch when using `--verify-discount`

### Notification Scripts

| Windows | Linux/macOS | Description |
|---------|-------------|-------------|
| `windows\notify-email.ps1` | `linux/notify-email.sh` | Send email report |
| `windows\notify-sms.ps1` | `linux/notify-sms.sh` | Send SMS alert |
| `windows\notify-toast.ps1` | `linux/notify-desktop.sh` | Desktop notification |

**Email Subjects:**
- Service down: "EZPass Monitor - Service Currently Unavailable"
- Error: "EZPass Monitor Error - Failed to retrieve toll data"
- No discount: "EZPass Alert: No Discount - Potential $X.XX savings with Gold"
- Bronze: "EZPass Alert: Bronze (20%) - $X.XX more with Gold"
- Gold: "EZPass Alert: Gold (40%) - Saving $X.XX this month!"

## Session Caching

The tool automatically caches your login session for 10 minutes to prevent "account already logged in" errors when running multiple times.

**Windows cache location:** `~\.ezpass\cookies.xml`
**Linux/macOS cache location:** `~/.ezpass/cookies.txt`

**How it works:**
- First run: Logs in and saves session cookies
- Subsequent runs (within 10 min): Reuses cached session, no login needed
- After 10 min: Cache expires, performs fresh login

## Error Handling

### Service Unavailable

When the EZPass website is down for maintenance:

```
ERROR: Maine EZPass service is currently unavailable
The website shows: 'The online Maine Customer Service Center is currently unavailable.'
This is likely due to maintenance or technical issues on their end.
Please try again later (in 30 minutes to a few hours).
```

### Login Conflicts

If your account is already logged in elsewhere, the script automatically waits 90 seconds and retries. Future runs within 10 minutes use the cached session to avoid this.

## Automation

### Windows: Task Scheduler

1. Open Task Scheduler (`taskschd.msc`)
2. Create Basic Task:
   - **Name:** EZPass Weekly Report
   - **Trigger:** Weekly, Fridays at 6:00 PM
   - **Action:** Start a program
   - **Program:** `powershell.exe`
   - **Arguments:** `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\windows\notify-email.ps1"`
   - **Start in:** `C:\path\to\windows`

### Linux/macOS: cron

Add a cron job for weekly email reports:

```bash
# Edit crontab
crontab -e

# Add weekly Friday 6 PM report
0 18 * * 5 /path/to/linux/notify-email.sh >> /tmp/ezpass-cron.log 2>&1

# Add daily check (only sends if not Gold tier)
0 18 * * * /path/to/linux/check-tolls.sh --estimate > /dev/null 2>&1 || /path/to/linux/notify-email.sh >> /tmp/ezpass-cron.log 2>&1
```

## Troubleshooting

### Windows: Execution Policy Error

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Login Fails

1. Verify credentials at https://ezpassmaineturnpike.com
2. Delete session cache: `~\.ezpass\cookies.xml` (Windows) or `~/.ezpass/cookies.txt` (Linux/macOS)
3. Wait 5 minutes if "already logged in" error persists
4. Run setup again to reconfigure credentials

### Email Not Sending

**Gmail users:**
1. Enable 2-Factor Authentication
2. Create App Password at https://myaccount.google.com/apppasswords
3. Use the 16-character app password (not your regular password)

**Other providers:**
- Outlook/Hotmail: `smtp.office365.com:587`
- Yahoo: `smtp.mail.yahoo.com:587` (requires app password)

## Configuration Files

### Windows: ~\.ezpass\config.xml

Secure configuration file encrypted with Windows Data Protection API (DPAPI).

### Linux/macOS: ~/.ezpass/config.json + credential store

Non-sensitive settings stored in plaintext JSON. Credentials stored via:
- **macOS**: Keychain (`security` command)
- **Linux**: `pass` (standard Unix password manager) if available
- **Fallback**: OpenSSL AES-256-CBC encrypted file (`~/.ezpass/config.enc`)

See **[CONFIGURATION.md](CONFIGURATION.md)** for full details.

## Files

```
EzPassMonitor/
├── windows/                    # Windows PowerShell scripts
│   ├── check-tolls.bat         # Double-click launcher
│   ├── check-tolls.ps1         # Main toll checking script
│   ├── setup.ps1               # Interactive setup wizard
│   ├── notify-email.ps1        # Email notification wrapper
│   ├── notify-sms.ps1          # SMS notification wrapper
│   └── notify-toast.ps1        # Windows toast notifications
├── linux/                      # Linux/macOS Bash scripts
│   ├── lib/
│   │   └── credentials.sh      # Credential storage helper
│   ├── check-tolls             # Quick launcher
│   ├── check-tolls.sh          # Main toll checking script
│   ├── setup.sh                # Interactive setup wizard
│   ├── notify-email.sh         # Email notification wrapper
│   ├── notify-sms.sh           # SMS notification wrapper
│   └── notify-desktop.sh       # Desktop notifications
├── README.md                   # This file
├── QUICK-START.md              # Quick start guide
├── NOTIFICATIONS.md            # Notification setup guide
├── CONFIGURATION.md            # Configuration reference
├── LICENSE                     # GNU GPL v3.0
└── .gitignore
```

**Runtime configuration (not in repo):**
- Windows: `~\.ezpass\config.xml`, `~\.ezpass\cookies.xml`
- Linux/macOS: `~/.ezpass/config.json`, `~/.ezpass/config.enc`, `~/.ezpass/cookies.txt`

## See Also

- **[QUICK-START.md](QUICK-START.md)** - Get started quickly
- **[NOTIFICATIONS.md](NOTIFICATIONS.md)** - Complete notification setup guide
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration file reference

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
