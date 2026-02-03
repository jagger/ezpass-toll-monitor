# Quick Start Guide

Get started monitoring your Maine EZPass tolls.

## Windows

### Setup (One Time)

Open PowerShell in the `windows/` folder and run:

```powershell
.\setup.ps1
```

This interactive wizard will:
1. Configure your EZPass credentials (encrypted with DPAPI)
2. Optionally setup email notifications
3. Optionally setup SMS notifications
4. Test the connection
5. Save everything securely

**For Gmail users:** You'll need to create an App Password (requires 2FA enabled).

### Daily Use

**Easy way** - Double-click:
```
windows\check-tolls.bat
```

**PowerShell way:**
```powershell
windows\check-tolls.ps1 -Estimate
```

### Send Notifications

```powershell
windows\notify-email.ps1    # Email (detailed report)
windows\notify-sms.ps1      # SMS (compact alert)
windows\notify-toast.ps1    # Windows Toast notification
```

### Automation

Set up weekly email reports using Windows Task Scheduler:

1. Open Task Scheduler (`Win+R` → `taskschd.msc`)
2. Create Basic Task
3. **Trigger:** Weekly, Friday at 6 PM
4. **Action:** Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\path\to\windows\notify-email.ps1"`

---

## Linux / macOS

### Setup (One Time)

```bash
chmod +x linux/*.sh linux/lib/*.sh linux/check-tolls
linux/setup.sh
```

This interactive wizard will:
1. Configure your EZPass credentials (stored via macOS Keychain, `pass`, or OpenSSL)
2. Optionally setup email notifications
3. Optionally setup SMS notifications
4. Test the connection
5. Save settings to `~/.ezpass/config.json`

**For Gmail users:** You'll need to create an App Password (requires 2FA enabled).

### Daily Use

**Quick launcher:**
```bash
linux/check-tolls
```

**Full options:**
```bash
linux/check-tolls.sh --estimate
```

### Send Notifications

```bash
linux/notify-email.sh      # Email (detailed report)
linux/notify-sms.sh        # SMS (compact alert)
linux/notify-desktop.sh    # Desktop notification (notify-send / osascript)
```

### Automation

Set up weekly email reports using cron:

```bash
# Edit crontab
crontab -e

# Add weekly Friday 6 PM report
0 18 * * 5 /path/to/linux/notify-email.sh >> /tmp/ezpass-cron.log 2>&1
```

---

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

## Files

| Windows | Linux/macOS | Purpose |
|---------|-------------|---------|
| `windows\setup.ps1` | `linux/setup.sh` | Interactive configuration wizard |
| `windows\check-tolls.ps1` | `linux/check-tolls.sh` | Main toll checking script |
| `windows\check-tolls.bat` | `linux/check-tolls` | Quick launcher |
| `windows\notify-email.ps1` | `linux/notify-email.sh` | Email notifications |
| `windows\notify-sms.ps1` | `linux/notify-sms.sh` | SMS notifications |
| `windows\notify-toast.ps1` | `linux/notify-desktop.sh` | Desktop notifications |
| `~\.ezpass\config.xml` | `~/.ezpass/config.json` | Your settings |

## Troubleshooting

**Windows - Can't run scripts?**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Linux - Permission denied?**
```bash
chmod +x linux/*.sh linux/lib/*.sh linux/check-tolls
```

**Email not sending?**
- Gmail: Use App Password, not regular password
- Run setup again to reconfigure

**Wrong toll counts?**
- Verify credentials at https://ezpassmaineturnpike.com
- Run setup again to update credentials

**Need help?**
- Check `README.md` for detailed documentation
- See `NOTIFICATIONS.md` for notification troubleshooting
