# EZPass Toll Monitor - Notification Guide

This guide covers all the ways you can receive automated alerts about your toll discount tier.

## Discount Tiers

- **0-29 tolls**: No discount
- **30-39 tolls**: 20% discount (Bronze tier)
- **40+ tolls**: 40% discount (Gold tier)

---

## Option 1: Email Notifications

### Gmail Setup (Recommended)

1. **Enable 2-Factor Authentication** on your Google account
2. **Create an App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Windows Computer"
   - Copy the 16-character password

3. **Save Email Configuration**:
```powershell
.\notify-email.ps1 `
    -From "your-email@gmail.com" `
    -To "your-email@gmail.com" `
    -EmailPassword "your-app-password" `
    -SaveEmailConfig
```

4. **Test It**:
```powershell
.\notify-email.ps1
```

### Other Email Providers

**Outlook/Hotmail**:
```powershell
.\notify-email.ps1 `
    -SmtpServer "smtp.office365.com" `
    -Port 587 `
    -From "your-email@outlook.com" `
    -To "your-email@outlook.com" `
    -EmailPassword "your-password" `
    -SaveEmailConfig
```

**Yahoo**:
```powershell
.\notify-email.ps1 `
    -SmtpServer "smtp.mail.yahoo.com" `
    -Port 587 `
    -From "your-email@yahoo.com" `
    -To "your-email@yahoo.com" `
    -EmailPassword "your-app-password" `
    -SaveEmailConfig
```

**Custom SMTP**:
```powershell
.\notify-email.ps1 `
    -SmtpServer "mail.example.com" `
    -Port 587 `
    -From "you@example.com" `
    -To "you@example.com" `
    -EmailUsername "smtp-username" `
    -EmailPassword "smtp-password" `
    -UseSsl $true `
    -SaveEmailConfig
```

### Selective Notifications

Only get notified for specific discount tiers:

```powershell
# Only notify for 20% and 40% discount tiers
.\notify-email.ps1 -OnlyAlertOnTiers "Bronze,Gold"

# Only notify when you have no discount
.\notify-email.ps1 -OnlyAlertOnTiers "None"

# Only notify for maximum discount
.\notify-email.ps1 -OnlyAlertOnTiers "Gold"
```

---

## Option 2: Windows Toast Notifications

Simple desktop notifications on Windows 10/11.

### Usage

```powershell
# Show notification for all tiers
.\notify-toast.ps1

# Only show for specific tiers
.\notify-toast.ps1 -OnlyAlertOnTiers "Bronze,Gold"
```

---

## Option 3: SMS Notifications (via Email-to-SMS)

Many carriers support email-to-SMS. Send emails to these addresses:

| Carrier | Email Format |
|---------|-------------|
| Verizon | `your-number@vtext.com` |
| AT&T | `your-number@txt.att.net` |
| T-Mobile | `your-number@tmomail.net` |
| Sprint | `your-number@messaging.sprinttpcs.com` |
| US Cellular | `your-number@email.uscc.net` |

**Example**:
```powershell
.\notify-email.ps1 `
    -From "your-email@gmail.com" `
    -To "5555551234@vtext.com" `
    -EmailPassword "your-app-password" `
    -OnlyAlertOnTiers "Bronze,Gold"
```

---

## Option 4: Multiple Notifications

Create a wrapper script for both email AND toast:

**`notify-all.ps1`**:
```powershell
# Send email
.\notify-email.ps1 -OnlyAlertOnTiers "Bronze,Gold"

# Show toast notification
.\notify-toast.ps1 -OnlyAlertOnTiers "Bronze,Gold"
```

Then run:
```powershell
.\notify-all.ps1
```

---

## Automating Notifications

### Task Scheduler Setup

1. Open Task Scheduler (Win+R → `taskschd.msc`)
2. Click "Create Basic Task"
3. Name: "EZPass Toll Monitor"
4. Trigger: **Weekly, every Friday at 6:00 PM**
5. Action: **Start a program**
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\jagge\Documents\tolls\notify-email.ps1"`
   - Start in: `C:\Users\jagge\Documents\tolls`

### Multiple Schedules

Set up different schedules for different notification methods:

**Weekly Email Summary** (Fridays at 6 PM):
- Arguments: `-ExecutionPolicy Bypass -File "C:\Users\jagge\Documents\tolls\notify-email.ps1"`

**Mid-Month Check** (15th of each month):
- Arguments: `-ExecutionPolicy Bypass -File "C:\Users\jagge\Documents\tolls\notify-toast.ps1" -OnlyAlertOnTiers "Bronze"`

**End of Month Warning** (28th of each month):
- Arguments: `-ExecutionPolicy Bypass -File "C:\Users\jagge\Documents\tolls\notify-email.ps1" -OnlyAlertOnTiers "None,Bronze"`

---

## Notification Examples

### Gold Tier (40% Discount) Email

**Subject**: 🎉 EZPass Alert: Gold Tier - 40% Discount (40+ tolls)

```
============================================================
TOLL REPORT FOR 1/2026
============================================================
Total tolls posted: 43
Discount-eligible tolls: 43
============================================================

Current day: 15 of 31
Estimated month-end discount-eligible tolls: 89.1
============================================================

📊 Projected Discount Tier: Gold
   40% discount - Maximum savings!
   Estimated: 89.1 tolls
```

### Bronze Tier (20% Discount) Email

**Subject**: 💰 EZPass Alert: Bronze Tier - 20% Discount (30-39 tolls)

```
============================================================
TOLL REPORT FOR 1/2026
============================================================
Total tolls posted: 18
Discount-eligible tolls: 18
============================================================

Current day: 15 of 31
Estimated month-end discount-eligible tolls: 37.2
============================================================

📊 Projected Discount Tier: Bronze
   20% discount
   Estimated: 37.2 tolls

💡 Need 2.8 more tolls for 40% discount
⚠️  Or reduce by 8.2 tolls to drop to no discount tier
```

### No Discount Email

**Subject**: ⚠️ EZPass Alert: No Discount Tier (0-29 tolls)

```
============================================================
TOLL REPORT FOR 1/2026
============================================================
Total tolls posted: 8
Discount-eligible tolls: 8
============================================================

Current day: 15 of 31
Estimated month-end discount-eligible tolls: 16.5
============================================================

📊 Projected Discount Tier: None
   No discount
   Estimated: 16.5 tolls

💡 Need 13.5 more tolls for 20% discount
```

---

## Troubleshooting

### Email Not Sending

1. **Gmail "Less secure app" error**:
   - Use an App Password (requires 2FA enabled)
   - Don't use your regular Gmail password

2. **Authentication failed**:
   - Verify username/password are correct
   - Check SMTP server and port
   - Ensure SSL is enabled for most providers

3. **Test email settings**:
   ```powershell
   Test-NetConnection -ComputerName smtp.gmail.com -Port 587
   ```

### Toast Notifications Not Showing

1. **Check Windows notification settings**:
   - Settings → System → Notifications
   - Ensure notifications are enabled

2. **Focus Assist**:
   - Notifications may be suppressed by Focus Assist
   - Check system tray icon

### SMS Not Received

1. **Verify carrier gateway**:
   - Carrier gateways change occasionally
   - Google "your carrier email to SMS gateway"

2. **Message limits**:
   - Some carriers block or limit email-to-SMS
   - Try a different notification method

---

## Security Best Practices

1. **Use App Passwords**: Never use your main email password
2. **Secure Config Files**: The config files store passwords in plain text
   - Set file permissions: `icacls config.json /inheritance:r /grant:r "$env:USERNAME:F"`
3. **Separate Email Account**: Consider using a dedicated email for automation
4. **Environment Variables**: Advanced users can use environment variables instead of config files

---

## Exit Codes

The scripts return these exit codes (useful for Task Scheduler):

- **1**: Gold tier (40% discount)
- **2**: Bronze tier (20% discount)
- **3**: No discount tier
- **0**: Notification sent successfully (from notify scripts)

You can use these in Task Scheduler to trigger different actions based on tier.
