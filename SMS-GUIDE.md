# SMS Notifications Guide

Get EZPass toll alerts sent directly to your phone via text message (SMS).

## Overview

SMS notifications use **email-to-SMS gateways** provided by mobile carriers. This sends toll status updates as text messages to your phone - compact, instant, and perfect for at-a-glance monitoring.

## SMS Message Format

Messages use a compact progress bar format optimized for mobile:

### Gold Tier (40+ tolls)
```
EZPass: [████████] 62/40
Gold 40% | -$24.80/mo
```

### Bronze Tier (30-39 tolls)
```
EZPass: [█████░░░] 35/40
Bronze 20% | 5→Gold +$6.20
```

### No Discount (<30 tolls)
```
EZPass: [██░░░░░░] 8/40
Est 62 → Gold -$24.80
```

**Benefits:**
- Under 80 characters (SMS-safe)
- Visual progress bar for quick status
- Clear actionable information
- Cost-effective (minimal SMS charges)

## Quick Setup

### 1. Run Interactive Setup

```powershell
.\setup.ps1
```

The setup wizard will guide you through:
1. EZPass credentials
2. Email configuration (required for SMS)
3. SMS configuration with carrier selection

### 2. Configure SMS

When prompted for SMS setup:
- Choose your mobile carrier
- Enter your 10-digit phone number
- Select notification preferences

### 3. Test SMS

The setup will offer to send a test SMS to verify configuration.

## Supported Carriers

### Major US Carriers

| Carrier | Email-to-SMS Gateway | Example |
|---------|---------------------|---------|
| **Verizon** | `@vtext.com` | `5551234567@vtext.com` |
| **AT&T** | `@txt.att.net` | `5551234567@txt.att.net` |
| **T-Mobile** | `@tmomail.net` | `5551234567@tmomail.net` |
| **Sprint** | `@messaging.sprintpcs.com` | `5551234567@messaging.sprintpcs.com` |

### Other Carriers

If your carrier isn't listed, you can manually enter the email-to-SMS gateway. Contact your carrier's support or search online for "[carrier name] email to SMS gateway".

## Manual Configuration

The configuration is stored in `~\.ezpass\config.xml`:

```powershell
@{
    SMS = @{
        To = "5551234567@vtext.com"    # Your phone number + carrier gateway
        OnlyAlertOnTiers = ""           # Notification filter (see below)
        Carrier = "Verizon"             # Carrier name
    }
}
```

## Notification Preferences

Control when SMS notifications are sent:

| Setting | Behavior |
|---------|----------|
| `""` (empty) | Notify for all tiers |
| `"Bronze,Gold"` | Only notify for Bronze (20%) and Gold (40%) tiers |
| `"Gold"` | Only notify for Gold (40%) tier |
| `"None"` | Only notify when no discount tier |

**Note:** Error notifications (login failures, service unavailable) are always sent.

## Usage

### Send SMS Notification

```powershell
.\notify-sms.ps1
```

This will:
1. Run toll check with SMS format
2. Send compact status to your phone
3. Display results in console

### Test SMS Format

See what the SMS will look like without sending:

```powershell
.\check-tolls.ps1 -Estimate -SmsFormat
```

Output example:
```
EZPass: [█████░░░] 35/40
Bronze 20% | 5→Gold +$6.20
```

### Automate SMS Alerts

Set up Windows Task Scheduler to send regular SMS updates:

**Weekly SMS (Fridays at 6 PM):**
```
Program: powershell.exe
Arguments: -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\notify-sms.ps1"
Start in: C:\path\to\prod
```

**Daily SMS (Bronze or lower only):**
Create a custom script:
```powershell
# daily-sms-alert.ps1
cd C:\path\to\prod

$output = .\check-tolls.ps1 -Estimate -SmsFormat
$exitCode = $LASTEXITCODE

# Only send SMS if not at Gold tier
if ($exitCode -ne 1) {
    .\notify-sms.ps1
}
```

## Costs and Limits

### SMS Charges
- **Most carriers:** Include SMS in unlimited plans (free)
- **Pay-per-text plans:** May incur standard SMS rates
- **Email-to-SMS:** Usually counts as one incoming text

### Message Length
- SMS format is under 80 characters
- Avoids multi-part SMS charges
- One message per notification

### Frequency
Consider notification frequency to avoid carrier spam filters:
- **Daily:** Usually fine
- **Multiple times per day:** May trigger filters
- **Every few hours:** Not recommended

## Troubleshooting

### SMS Not Received

**1. Verify Gateway Address**
- Confirm your carrier's email-to-SMS gateway
- Try sending a manual email to your SMS gateway
- Some carriers have changed their gateways

**2. Check Carrier Settings**
- Some carriers require opt-in for email-to-SMS
- Log into your carrier account and check SMS settings
- Verizon users: Enable "text online" feature

**3. Spam Filters**
- Email-to-SMS may be blocked by carrier spam filters
- Add sender email to contacts/allowed list
- Some carriers block by default - contact support

**4. Delays**
- Email-to-SMS can have 1-5 minute delays
- Delays are normal, especially during peak hours
- Wait a few minutes before troubleshooting

### Email Configuration Required

SMS notifications require email configuration because they use email-to-SMS gateways.

If you see: `"Error: SMS not configured"` or `"SMS requires email configuration"`:

1. Run `.\setup.ps1`
2. Configure email first
3. Then configure SMS

### Wrong Format Received

If you receive a full toll report instead of compact SMS:

1. Verify script usage: `.\notify-sms.ps1` (not `.\notify-email.ps1`)
2. Check that `notify-sms.ps1` uses `-SmsFormat` flag
3. Update to latest version of scripts

### Testing SMS

Test SMS without modifying configuration:

```powershell
# Test with manual phone number
$testSmsAddress = "5551234567@vtext.com"
$body = & .\check-tolls.ps1 -Estimate -SmsFormat | Out-String

Send-MailMessage `
    -From "your-email@gmail.com" `
    -To $testSmsAddress `
    -Subject "Test" `
    -Body $body `
    -SmtpServer "smtp.gmail.com" `
    -Port 587 `
    -UseSsl `
    -Credential (Get-Credential)
```

## Advanced Usage

### Multiple Phone Numbers

Send SMS to multiple phones by adding recipients:

Edit `notify-sms.ps1`:
```powershell
$emailParams = @{
    From = $emailConfig.From
    To = @(
        $smsConfig.To,
        "5559876543@txt.att.net"  # Add second number
    )
    # ... rest of config
}
```

### Custom SMS Format

Create your own ultra-compact format by editing `check-tolls.ps1`:

```powershell
# Ultra-minimal (under 40 chars)
Write-Output "EZP: $tollCount/40 $tier $([Math]::Round($savings, 0))"
# Example: "EZP: 35/40 Bronze $12"
```

### Combining Email and SMS

Send detailed email + compact SMS:

```powershell
# combined-notify.ps1
.\notify-email.ps1   # Detailed email report
.\notify-sms.ps1     # Compact SMS alert
```

### Conditional SMS

Only send SMS when action needed:

```powershell
# smart-sms.ps1
$output = .\check-tolls.ps1 -Estimate -SmsFormat
$exitCode = $LASTEXITCODE

# Only alert if close to tier boundary
if ($exitCode -eq 2) {  # Bronze tier
    .\notify-sms.ps1
}
```

## Carrier-Specific Notes

### Verizon
- Reliable email-to-SMS gateway
- May require "text online" feature enabled
- Gateway: `@vtext.com`

### AT&T
- Supports email-to-SMS by default
- Subject line may appear in some phones
- Gateway: `@txt.att.net`

### T-Mobile
- Good email-to-SMS support
- Occasional delays during peak hours
- Gateway: `@tmomail.net`

### Sprint (now part of T-Mobile)
- Legacy gateway still works
- Consider switching to T-Mobile gateway
- Gateway: `@messaging.sprintpcs.com`

### MVNOs (Mint, Cricket, Metro, etc.)
- Usually use parent carrier's gateway
- Check with provider for specific gateway
- May have additional restrictions

## Security Considerations

### SMS vs Email
- SMS is less secure than email
- Messages may be readable in notification previews
- Consider for status only, not sensitive data

### Recommendations
- Use notification filters to reduce message frequency
- Don't include account numbers in SMS
- Current format shows only toll counts and tiers (safe)

## FAQ

**Q: Is SMS free?**
A: Most unlimited plans include incoming SMS at no cost. Email-to-SMS typically counts as one incoming text message.

**Q: Can I use SMS without email?**
A: No, SMS notifications require email configuration because they use email-to-SMS gateways.

**Q: Why use email-to-SMS instead of true SMS API?**
A: Email-to-SMS is free, simple, and doesn't require API keys or paid SMS services.

**Q: What if my carrier isn't listed?**
A: Choose "Other" during setup and manually enter your carrier's email-to-SMS gateway. Search "[carrier] email to SMS gateway" online.

**Q: Can I get SMS in other countries?**
A: Email-to-SMS is primarily a US carrier feature. International users should check with their carrier for equivalent services.

**Q: How do I disable SMS notifications?**
A: Run `.\setup.ps1` again and choose "No" for SMS setup, or delete the SMS section from `~\.ezpass\config.xml`.

## See Also

- **[NOTIFICATIONS-GUIDE.md](NOTIFICATIONS-GUIDE.md)** - Email notification setup
- **[README.md](README.md)** - Main project documentation
- **[CONFIGURATION.md](CONFIGURATION.md)** - Configuration file details
