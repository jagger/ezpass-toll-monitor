# 🚀 Quick Start Guide

## First Time Setup (2 minutes)

### Step 1: Configure Your EZPass Credentials

Open PowerShell in this folder and run:

```powershell
.\setup.ps1
```

Enter your Maine EZPass username and password when prompted. This will save your credentials and test the connection.

### Step 2: Setup Email Notifications (Optional)

```powershell
.\setup-email.ps1
```

Follow the wizard to configure email alerts. **For Gmail users**: You'll need to create an App Password (requires 2FA).

---

## Daily Use

### Check Your Toll Status

**Easy way** - Just double-click:
```
check-tolls.bat
```

**PowerShell way**:
```powershell
.\check-tolls.ps1 -Estimate
```

### Get Email Alert

```powershell
.\notify-email.ps1
```

### Get Windows Notification

```powershell
.\notify-toast.ps1
```

---

## Understanding Your Results

### Sample Output

```
============================================================
TOLL REPORT FOR 1/2026
============================================================
Total tolls posted: 35
Discount-eligible tolls: 35
============================================================

Current day: 15 of 31
Estimated month-end discount-eligible tolls: 72.3
============================================================

📊 Projected Discount Tier: Gold
   40% discount - Maximum savings!
   Estimated: 72.3 tolls
```

### Discount Tiers

| Tolls/Month | Discount | Tier |
|-------------|----------|------|
| 0-29 | 0% | None |
| 30-39 | 20% | Bronze |
| 40+ | 40% | Gold |

---

## Automation

### Weekly Email Report

Set this up once and forget it:

1. Open **Task Scheduler** (Win+R → `taskschd.msc`)
2. Click **Create Basic Task**
3. Name: `EZPass Weekly Report`
4. Trigger: **Weekly, Friday at 6:00 PM**
5. Action: **Start a program**
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Users\jagge\Documents\tolls\notify-email.ps1"`
   - Start in: `C:\Users\jagge\Documents\tolls`
6. Click **Finish**

Now you'll automatically get an email every Friday with your toll status!

---

## Files in This Folder

| File | Purpose |
|------|---------|
| `check-tolls.ps1` | Main script - checks toll count |
| `notify-email.ps1` | Send email notifications |
| `notify-toast.ps1` | Show Windows notifications |
| `setup.ps1` | Interactive setup for credentials |
| `setup-email.ps1` | Interactive email setup |
| `check-tolls.bat` | Double-click launcher |
| `config.json` | Your saved credentials |
| `email-config.json` | Your saved email settings |
| `README.md` | Complete documentation |
| `NOTIFICATIONS-GUIDE.md` | Detailed notification setup |
| `QUICK-START.md` | This file! |

---

## Common Questions

**Q: How accurate is the estimate?**
A: It calculates your daily average and projects to month-end. Accuracy improves as the month progresses.

**Q: When should I check?**
A: Mid-month (around the 15th) gives a good projection. Check again near month-end if you're close to a tier boundary.

**Q: I'm at 35 tolls projected - should I use the turnpike more?**
A: You're in the Bronze tier (20% discount). If you can add 5+ more trips, you'll jump to Gold tier (40% discount). Run the numbers to see if the extra trips are worth it!

**Q: I'm at 28 tolls projected - what should I do?**
A: You're close to no discount. Either:
- Add 2+ trips to reach Bronze (20% discount)
- Or stay under 30 if you don't need the discount

**Q: Are my credentials secure?**
A: They're stored in plain text `config.json` file. Keep this file secure and don't share it. Consider setting file permissions to restrict access.

**Q: Can I check previous months?**
A: Yes! Use: `.\check-tolls.ps1 -Month 12 -Year 2025`

**Q: My login fails**
A: Verify your credentials work at https://ezpassmaineturnpike.com. If they work there but not in the script, the website structure may have changed.

---

## Gmail App Password Setup

If using Gmail for notifications:

1. Go to https://myaccount.google.com/security
2. Enable **2-Step Verification** (if not already on)
3. Go to https://myaccount.google.com/apppasswords
4. Select **Mail** and **Windows Computer**
5. Click **Generate**
6. Copy the 16-character password
7. Use this in `setup-email.ps1` (NOT your regular Gmail password)

---

## Getting Help

- 📖 **Complete docs**: See `README.md`
- 📧 **Notification setup**: See `NOTIFICATIONS-GUIDE.md`
- 🐛 **Issues**: Check the Troubleshooting sections in README.md

---

## Tips & Tricks

### Check Multiple Months

```powershell
# Check last 3 months
foreach ($i in 1..3) {
    $date = (Get-Date).AddMonths(-$i)
    .\check-tolls.ps1 -Month $date.Month -Year $date.Year
}
```

### Get SMS + Email

Create `notify-all.ps1`:
```powershell
# Email to inbox
.\notify-email.ps1 -To "you@gmail.com"

# SMS via email-to-text
.\notify-email.ps1 -To "5555551234@vtext.com"
```

### Monthly Summary

Run this on the last day of the month:
```powershell
.\check-tolls.ps1 -Verbose | Out-File "toll-summary-$(Get-Date -Format 'yyyy-MM').txt"
```

---

## Support

This is a community-created tool. If you find it useful, consider sharing it with other Maine EZPass users!

**Disclaimer**: This tool is not affiliated with Maine Turnpike Authority. Always verify toll information on the official website.
