# Quick Start Guide

Get started monitoring your Maine EZPass tolls in 5 minutes.

## Setup (One Time)

Open PowerShell in this folder and run:

```powershell
.\setup.ps1
```

This interactive wizard will:
1. Configure your EZPass credentials (encrypted)
2. Optionally setup email notifications
3. Optionally setup SMS notifications
4. Test the connection
5. Save everything securely

**For Gmail users:** You'll need to create an App Password (requires 2FA enabled).

## Daily Use

### Quick Check

**Easy way** - Double-click:
```
check-tolls.bat
```

**PowerShell way:**
```powershell
.\check-tolls.ps1 -Estimate
```

### Send Notifications

**Email (detailed report):**
```powershell
.\notify-email.ps1
```

**SMS (compact alert):**
```powershell
.\notify-sms.ps1
```

**Windows Toast:**
```powershell
.\notify-toast.ps1
```

## Understanding Your Status

### Discount Tiers

- **0-29 tolls/month**: No discount
- **30-39 tolls/month**: 20% discount (Bronze)
- **40+ tolls/month**: 40% discount (Gold) - Maximum savings!

### Example Output

```
TOLL REPORT FOR 1/2026
============================================================
Total tolls posted: 35
Discount-eligible tolls: 35
============================================================

Current day: 15 of 31
Estimated month-end discount-eligible tolls: 72.3
============================================================

>> Projected Discount Tier: Gold
   40% discount - Maximum savings!
   Estimated: 72.3 tolls
```

### SMS Format

Compact progress bar for text messages:

```
EZPass: [█████░░░] 35/40
Bronze 20% | 5→Gold +$6.20
```

## Automation

Set up weekly email reports using Windows Task Scheduler:

1. Open Task Scheduler (`Win+R` → `taskschd.msc`)
2. Create Basic Task
3. **Trigger:** Weekly, Friday at 6 PM
4. **Action:** Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\notify-email.ps1"`

## Files

| File | Purpose |
|------|---------|
| `setup.ps1` | Interactive configuration wizard |
| `check-tolls.ps1` | Main toll checking script |
| `check-tolls.bat` | Double-click launcher |
| `notify-email.ps1` | Email notifications |
| `notify-sms.ps1` | SMS notifications |
| `notify-toast.ps1` | Desktop notifications |
| `~\.ezpass\config.xml` | Your encrypted settings |

## Next Steps

- **Automation:** Set up Task Scheduler for weekly reports
- **Notifications:** See `NOTIFICATIONS.md` for detailed setup
- **Configuration:** See `CONFIGURATION.md` for advanced options
- **Full Docs:** See `README.md` for complete documentation

## Troubleshooting

**Can't run scripts?**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Email not sending?**
- Gmail: Use App Password, not regular password
- Run `.\setup.ps1` to reconfigure

**Wrong toll counts?**
- Verify credentials at https://ezpassmaineturnpike.com
- Run `.\setup.ps1` to update credentials

**Need help?**
- Check `README.md` for detailed documentation
- See `NOTIFICATIONS.md` for notification troubleshooting
