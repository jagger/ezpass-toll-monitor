# Notifications Guide

Get automated alerts about your EZPass toll discount status via email, SMS, or desktop notifications.

## Quick Setup

Run the interactive setup to configure all notification methods:

**Windows:**
```powershell
windows\setup.ps1
```

**Linux/macOS:**
```bash
linux/setup.sh
```

This will guide you through:
1. EZPass credentials (required)
2. Email notifications (optional)
3. SMS notifications (optional, requires email)

## Email Notifications

### Supported Providers

| Provider | SMTP Server | Port | Notes |
|----------|------------|------|-------|
| **Gmail** | `smtp.gmail.com` | 587 | Requires App Password (recommended) |
| **Outlook/Hotmail** | `smtp.office365.com` | 587 | Use regular password |
| **Yahoo** | `smtp.mail.yahoo.com` | 587 | Requires App Password |
| **Custom** | Your SMTP server | Usually 587 | Configure during setup |

### Gmail Setup (Recommended)

1. **Enable 2-Factor Authentication** on your Google account
2. **Create App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail"
   - Copy the 16-character password
3. **Run setup** and enter the app password when prompted

### Send Email Notification

**Windows:**
```powershell
windows\notify-email.ps1
```

**Linux/macOS:**
```bash
linux/notify-email.sh
```

Sends detailed toll report with:
- Current toll count and tier status
- Projected month-end tier
- Individual toll transactions
- Savings calculations
- Actionable recommendations

### Email Subject Examples

- **Gold:** "EZPass Alert: Gold (40%) - Saving $24.80 this month!"
- **Bronze:** "EZPass Alert: Bronze (20%) - $12.40 more with Gold"
- **No Discount:** "EZPass Alert: No Discount - Potential $37.60 savings with Gold"
- **Error:** "EZPass Monitor Error - Failed to retrieve toll data"

## SMS Notifications

### How It Works

SMS uses **email-to-SMS gateways** provided by mobile carriers. Messages are sent via email to your carrier's gateway address.

### Message Format

Compact progress bar format optimized for text messages (under 80 characters):

**Gold Tier (40+ tolls):**
```
EZPass: [████████] 62/40
Gold 40% | -$24.80/mo
```

**Bronze Tier (30-39 tolls):**
```
EZPass: [█████░░░] 35/40
Bronze 20% | 5→Gold +$6.20
```

**No Discount (<30 tolls):**
```
EZPass: [██░░░░░░] 8/40
Est 62 → Gold -$24.80
```

### Supported Carriers

| Carrier | Email-to-SMS Gateway | Example |
|---------|---------------------|---------|
| **Verizon** | `@vtext.com` | `5551234567@vtext.com` |
| **AT&T** | `@txt.att.net` | `5551234567@txt.att.net` |
| **T-Mobile** | `@tmomail.net` | `5551234567@tmomail.net` |
| **Sprint** | `@messaging.sprintpcs.com` | `5551234567@messaging.sprintpcs.com` |

**Note:** For other carriers, search "[carrier name] email to SMS gateway" online.

### Send SMS Notification

**Windows:**
```powershell
windows\notify-sms.ps1
```

**Linux/macOS:**
```bash
linux/notify-sms.sh
```

Sends compact SMS alert with toll status.

### SMS Requirements

- Email configuration (uses SMTP settings)
- Mobile carrier's email-to-SMS gateway
- 10-digit phone number

**SMS Costs:**
- Usually free on unlimited plans
- Counts as one incoming text message
- No multi-part SMS charges (under 80 chars)

## Desktop Notifications

### Windows

Windows 10/11 toast notifications:

```powershell
windows\notify-toast.ps1

# Only notify for specific tiers
windows\notify-toast.ps1 -OnlyAlertOnTiers "Bronze,Gold"
```

Shows native Windows notification with:
- Toll count and tier status
- Quick visual alert
- No external dependencies

### Linux

Uses `notify-send` (libnotify) for desktop notifications:

```bash
linux/notify-desktop.sh

# Only notify for specific tiers
linux/notify-desktop.sh --only-alert-on-tiers "Bronze,Gold"
```

Tier-based urgency levels:
- **Gold**: low urgency
- **Bronze**: normal urgency
- **No discount**: critical urgency

**Requirement:** Install `libnotify` (`sudo apt install libnotify-bin` on Debian/Ubuntu, `sudo dnf install libnotify` on Fedora).

Falls back to terminal output if `notify-send` is not available.

### macOS

Uses `osascript` for native macOS notifications:

```bash
linux/notify-desktop.sh
```

No additional dependencies needed on macOS.

## Notification Preferences

Control when notifications are sent during setup:

| Setting | Behavior |
|---------|----------|
| **All tiers** | Always notify (default) |
| **Bronze + Gold** | Only notify for 20% and 40% tiers |
| **Gold only** | Only notify for 40% tier |
| **None only** | Only notify when no discount |

**Note:** Error notifications (login failures, service down) are always sent.

## Automation

### Windows: Task Scheduler

1. Open Task Scheduler (`Win+R` → `taskschd.msc`)
2. Create Basic Task
3. **Name:** EZPass Weekly Report
4. **Trigger:** Weekly, Friday at 6:00 PM
5. **Action:** Start a program
   - **Program:** `powershell.exe`
   - **Arguments:** `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\windows\notify-email.ps1"`
   - **Start in:** `C:\path\to\windows`

### Linux/macOS: cron

```bash
# Edit crontab
crontab -e

# Weekly Friday 6 PM email report
0 18 * * 5 /path/to/linux/notify-email.sh >> /tmp/ezpass-cron.log 2>&1

# Daily 6 PM SMS alert
0 18 * * * /path/to/linux/notify-sms.sh >> /tmp/ezpass-cron.log 2>&1

# Daily desktop notification at 6 PM
0 18 * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus /path/to/linux/notify-desktop.sh >> /tmp/ezpass-cron.log 2>&1
```

**Note:** Desktop notifications from cron require the `DISPLAY` and `DBUS_SESSION_BUS_ADDRESS` environment variables to be set.

### Daily SMS Alerts (Bronze or lower)

**Windows:**
```powershell
# daily-sms-check.ps1
$output = windows\check-tolls.ps1 -Estimate -SmsFormat
$exitCode = $LASTEXITCODE

# Only send SMS if not at Gold tier (exit code 1)
if ($exitCode -ne 1) {
    windows\notify-sms.ps1
}
```

**Linux/macOS:**
```bash
#!/bin/bash
# daily-sms-check.sh
linux/check-tolls.sh --estimate --sms-format > /dev/null 2>&1
exit_code=$?

# Only send SMS if not at Gold tier (exit code 1)
if [ "$exit_code" -ne 1 ]; then
    linux/notify-sms.sh
fi
```

### Multiple Notifications

**Windows:**
```powershell
windows\notify-email.ps1    # Detailed email
windows\notify-sms.ps1      # Quick SMS
windows\notify-toast.ps1    # Desktop alert
```

**Linux/macOS:**
```bash
linux/notify-email.sh       # Detailed email
linux/notify-sms.sh         # Quick SMS
linux/notify-desktop.sh     # Desktop alert
```

## Troubleshooting

### Email Not Sending

**Gmail:**
- Use App Password, not regular password
- Enable 2-Factor Authentication first
- Verify at https://myaccount.google.com/apppasswords

**Outlook/Hotmail:**
- Use regular password (no app password needed)
- SMTP: `smtp.office365.com`, Port: 587

**Yahoo:**
- Requires App Password
- Enable account security settings

**General:**
- Run setup again to reconfigure
- Windows: Test SMTP connection: `Test-NetConnection -ComputerName smtp.gmail.com -Port 587`
- Linux/macOS: Test SMTP connection: `curl -v smtps://smtp.gmail.com:465 2>&1 | head -20`
- Check firewall isn't blocking SMTP

### SMS Not Received

**Verify Gateway:**
- Confirm your carrier's email-to-SMS gateway
- Gateways sometimes change - search online for current address

**Carrier Settings:**
- Some carriers require opt-in for email-to-SMS
- Verizon: Enable "text online" feature
- AT&T: Check "Advanced Messaging" settings

**Delays:**
- Email-to-SMS can take 1-5 minutes
- Normal during peak hours

### Desktop Notifications Not Showing

**Windows:**
- Settings → System → Notifications → Ensure enabled
- Check Focus Assist isn't suppressing notifications

**Linux:**
- Install libnotify: `sudo apt install libnotify-bin` (Debian/Ubuntu)
- Check `notify-send --version` works
- From cron, ensure `DISPLAY` and `DBUS_SESSION_BUS_ADDRESS` are set

**macOS:**
- System Settings → Notifications → Allow notifications
- Check if Terminal/iTerm has notification permission

### Configuration Issues

**Reset Configuration:**

Windows:
```powershell
Remove-Item ~\.ezpass\config.xml
windows\setup.ps1
```

Linux/macOS:
```bash
rm ~/.ezpass/config.json ~/.ezpass/config.enc
linux/setup.sh
```

## Security

**Best Practices:**
- Use App Passwords (Gmail, Yahoo) instead of main password
- Windows: Config encrypted with DPAPI (only your user account can decrypt)
- Linux/macOS: Use `pass` for GPG-based encryption when available

**Credentials Stored:**
- Windows: `~\.ezpass\config.xml` - Encrypted with DPAPI
- Linux/macOS: Credential backend (Keychain / pass / OpenSSL) + `~/.ezpass/config.json` (non-sensitive only)

## Exit Codes

Scripts return these codes (useful for automation):

| Code | Meaning |
|------|---------|
| **1** | Gold tier (40+ tolls) |
| **2** | Bronze tier (30-39 tolls) OR error |
| **3** | No discount tier (0-29 tolls) |
| **0** | Notification sent successfully |

Use in conditional scripts:

**Windows:**
```powershell
windows\check-tolls.ps1 -Estimate
if ($LASTEXITCODE -eq 3) {
    windows\notify-sms.ps1
}
```

**Linux/macOS:**
```bash
linux/check-tolls.sh --estimate
if [ $? -eq 3 ]; then
    linux/notify-sms.sh
fi
```

## See Also

- **[README.md](README.md)** - Main documentation
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration file details
- **[QUICK-START.md](QUICK-START.md)** - Get started quickly
