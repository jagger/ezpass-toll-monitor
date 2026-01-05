# Notifications Guide

Get automated alerts about your EZPass toll discount status via email, SMS, or Windows notifications.

## Quick Setup

Run the interactive setup to configure all notification methods:

```powershell
.\setup.ps1
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
   - Select "Mail" and "Windows Computer"
   - Copy the 16-character password
3. **Run setup** and enter the app password when prompted

### Send Email Notification

```powershell
.\notify-email.ps1
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

```powershell
.\notify-sms.ps1
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

## Windows Toast Notifications

Desktop notifications for Windows 10/11.

```powershell
.\notify-toast.ps1
```

Shows native Windows notification with:
- Toll count and tier status
- Quick visual alert
- No external dependencies

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

### Weekly Email Report

Set up Windows Task Scheduler:

1. Open Task Scheduler (`Win+R` → `taskschd.msc`)
2. Create Basic Task
3. **Name:** EZPass Weekly Report
4. **Trigger:** Weekly, Friday at 6:00 PM
5. **Action:** Start a program
   - **Program:** `powershell.exe`
   - **Arguments:** `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\notify-email.ps1"`
   - **Start in:** `C:\path\to\prod`

### Daily SMS Alerts (Bronze or lower)

Create a wrapper script to only send when not at Gold tier:

```powershell
# daily-sms-check.ps1
$output = .\check-tolls.ps1 -Estimate -SmsFormat
$exitCode = $LASTEXITCODE

# Only send SMS if not at Gold tier (exit code 1)
if ($exitCode -ne 1) {
    .\notify-sms.ps1
}
```

### Multiple Notifications

Send both email and SMS:

```powershell
# combined-notify.ps1
.\notify-email.ps1   # Detailed email
.\notify-sms.ps1     # Quick SMS
.\notify-toast.ps1   # Desktop alert
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
- Generate app password in account settings

**General:**
- Run `.\setup.ps1` to reconfigure
- Test SMTP connection: `Test-NetConnection -ComputerName smtp.gmail.com -Port 587`
- Check firewall/antivirus isn't blocking SMTP

### SMS Not Received

**Verify Gateway:**
- Confirm your carrier's email-to-SMS gateway
- Gateways sometimes change - search online for current address
- Try sending manual email to gateway address

**Carrier Settings:**
- Some carriers require opt-in for email-to-SMS
- Log into carrier account and check SMS settings
- Verizon: Enable "text online" feature
- AT&T: Check "Advanced Messaging" settings

**Spam Filters:**
- Email-to-SMS may be blocked by carrier filters
- Add sender email to phone contacts
- Contact carrier support if persistent issues

**Delays:**
- Email-to-SMS can take 1-5 minutes
- Normal during peak hours
- Wait before troubleshooting

**Alternative:**
- If SMS fails, use email or toast notifications
- Some carriers don't support email-to-SMS reliably

### Toast Notifications Not Showing

**Windows Settings:**
- Settings → System → Notifications
- Ensure notifications enabled
- Check app-specific notification settings

**Focus Assist:**
- May suppress notifications
- Check system tray icon
- Temporarily disable during testing

### Configuration Issues

**Reset Configuration:**
```powershell
# Delete config and start fresh
Remove-Item ~\.ezpass\config.xml
.\setup.ps1
```

**Test Without Config:**
```powershell
# Manual test
.\check-tolls.ps1 -Username "your_user" -Password "your_pass" -Estimate
```

## Security

**Best Practices:**
- Use App Passwords (Gmail, Yahoo) instead of main password
- Config file is encrypted with Windows DPAPI
- Only your Windows user account can decrypt
- Keep your Windows account password secure

**Credentials Stored:**
- `~\.ezpass\config.xml` - Encrypted with DPAPI
- EZPass username and password (SecureString)
- Email password (SecureString)
- SMS phone number (not sensitive)

**DPAPI Protection:**
- Encryption tied to Windows user account
- Cannot be decrypted by other users
- Cannot be decrypted on different computers
- Lost if Windows account password is reset

## Exit Codes

Scripts return these codes (useful for automation):

| Code | Meaning |
|------|---------|
| **1** | Gold tier (40+ tolls) |
| **2** | Bronze tier (30-39 tolls) OR error |
| **3** | No discount tier (0-29 tolls) |
| **0** | Notification sent successfully |

Use in conditional scripts:
```powershell
.\check-tolls.ps1 -Estimate
if ($LASTEXITCODE -eq 3) {
    # Take action for no discount
    .\notify-sms.ps1
}
```

## Advanced Usage

### Test SMS Format

See what SMS will look like without sending:

```powershell
.\check-tolls.ps1 -Estimate -SmsFormat
```

### Custom Notification Script

Create your own logic:

```powershell
# smart-notify.ps1
$output = .\check-tolls.ps1 -Estimate
$exitCode = $LASTEXITCODE

switch ($exitCode) {
    1 {
        # Gold - quiet notification
        .\notify-toast.ps1
    }
    2 {
        # Bronze - email alert
        .\notify-email.ps1
    }
    3 {
        # No discount - urgent SMS + email
        .\notify-sms.ps1
        .\notify-email.ps1
    }
}
```

### Multiple Recipients

Edit `notify-sms.ps1` or `notify-email.ps1` to add recipients:

```powershell
# In notify-email.ps1 or notify-sms.ps1
$emailParams = @{
    To = @(
        $emailConfig.To,
        "second-email@example.com",
        "5559876543@vtext.com"  # Additional SMS
    )
    # ... rest of config
}
```

## FAQ

**Q: Which notification method is best?**
A: Email for details, SMS for quick status, Toast for desktop alerts. Use all three for different purposes.

**Q: Are SMS notifications free?**
A: Most unlimited plans include incoming SMS at no cost. Email-to-SMS counts as one text message.

**Q: Can I use SMS without email?**
A: No, SMS requires email configuration because it uses email-to-SMS gateways.

**Q: How often should I check?**
A: Weekly is usually sufficient. Daily if you're close to tier boundaries.

**Q: Can I get notifications in other countries?**
A: Email works worldwide. SMS email-to-SMS gateways are primarily US-based. International users should rely on email or toast.

**Q: What if my carrier isn't listed?**
A: Choose "Other" during setup and manually enter your carrier's gateway. Search "[carrier] email to SMS gateway".

**Q: Can I disable notifications temporarily?**
A: Yes, simply don't run the notify scripts. Automated tasks can be disabled in Task Scheduler.

## See Also

- **[README.md](README.md)** - Main documentation
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration file details
- **[QUICK-START.md](QUICK-START.md)** - Get started quickly
