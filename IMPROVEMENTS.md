# EZPass Toll Monitor - Recent Improvements

## 1. CSV Download Instead of HTML Scraping ✅
- **Old:** Scraped HTML table with complex regex
- **New:** Downloads CSV from `DownloadPostedTolls.do` endpoint
- **Benefits:** Cleaner, faster, more reliable parsing

## 2. Discounted Toll Amounts ✅
Shows actual cost after discount for each toll:
- **Gold Tier (40+ tolls):** Shows 40% discount per toll
- **Bronze Tier (30-39 tolls):** Shows 20% discount per toll
- **No Tier (<30 tolls):** Shows "[Eligible - no discount yet]"

Example:
```
Toll: $0.85 -> $0.51 (save $0.34 with 40% discount)
```

## 3. Potential Savings in Email Subject ✅
Subject line now shows money you could save:

- **No Discount:** "EZPass Alert: No Discount - Potential $1.50 savings with Gold"
- **Bronze (20%):** "EZPass Alert: Bronze (20%) - $0.75 more with Gold"
- **Gold (40%):** "EZPass Alert: Gold (40%) - Saving $1.50 this month!"

## 4. Prettier Transaction Display ✅
```
1. 01/03/2026 11:55:06 - MeTA:
   From Crabapple Cove (77) to Derry (181)
   Toll: $0.85 -> $0.51 (save $0.34 with 40% discount)
```

## Next Test
Wait 5 minutes for session to clear, then run:
```powershell
.\notify-email.ps1
```

Expected email will show:
- All 5 toll transactions with full details
- Discounted amounts (if applicable)
- Total savings summary
- Potential additional savings in subject line
