<#
.SYNOPSIS
Maine EZPass Toll Monitor for PowerShell

.DESCRIPTION
Checks if you're on track to post fewer than 40 discount-eligible tolls in a month.
Having fewer than 40 tolls triggers a 40% discount.

.PARAMETER Username
EZPass username

.PARAMETER Password
EZPass password

.PARAMETER Month
Month to check (1-12, default: current month)

.PARAMETER Year
Year to check (default: current year)

.PARAMETER Estimate
Estimate final toll count for the current month

.PARAMETER Verbose
Show detailed toll information and debug output

.PARAMETER SaveConfig
Save credentials to config file

.PARAMETER DownloadFile
Save CSV data to file for troubleshooting (toll-data-MM-YYYY.csv)

.EXAMPLE
.\check-tolls.ps1 -Username "jagger" -Password "yourpassword" -Estimate

.EXAMPLE
.\check-tolls.ps1 -SaveConfig

.EXAMPLE
.\check-tolls.ps1 -Verbose -DownloadFile
#>

param(
    [string]$Username,
    [string]$Password,
    [int]$Month,
    [int]$Year,
    [switch]$Estimate,
    [switch]$Verbose,
    [switch]$SaveConfig,
    [switch]$EmailOutput,
    [switch]$DownloadFile,
    [switch]$SmsFormat
)

# Secure config location in user home directory
$configDir = Join-Path $env:USERPROFILE ".ezpass"
$configFile = Join-Path $configDir "config.xml"

# Helper function to load secure config
function Get-SecureConfig {
    if (Test-Path $configFile) {
        try {
            return Import-Clixml -Path $configFile
        } catch {
            Write-Warning "Could not load config file: $_"
            return $null
        }
    }
    return $null
}

# Helper function to save secure config
function Save-SecureConfig {
    param($Config)

    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    $Config | Export-Clixml -Path $configFile -Force
}

# Load config file if it exists
$secureConfig = Get-SecureConfig

# Get credentials from config if not provided
if (-not $Username -and $secureConfig) {
    $Username = $secureConfig.EZPass.Username
    if ($secureConfig.EZPass.Password) {
        $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureConfig.EZPass.Password)
        )
    }
}

# Save config if requested
if ($SaveConfig) {
    if (-not $Username -or -not $Password) {
        Write-Host "Error: Please provide -Username and -Password to save config" -ForegroundColor Red
        exit 1
    }

    # Create or update config
    if (-not $secureConfig) {
        $secureConfig = @{
            EZPass = @{}
            Email = @{}
        }
    }

    $secureConfig.EZPass.Username = $Username
    $secureConfig.EZPass.Password = ConvertTo-SecureString $Password -AsPlainText -Force

    Save-SecureConfig -Config $secureConfig

    Write-Host "[OK] Credentials saved securely to: $configFile" -ForegroundColor Green
    Write-Host "Note: Credentials are encrypted and can only be read by your Windows user account." -ForegroundColor Green
    exit 0
}

# Validate credentials are available
if (-not $Username -or -not $Password) {
    Write-Host "Error: Username and password required." -ForegroundColor Red
    Write-Host ""
    Write-Host "First time setup:" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Or provide credentials manually:" -ForegroundColor Cyan
    Write-Host "  .\check-tolls.ps1 -Username 'user' -Password 'pass' -SaveConfig" -ForegroundColor White
    exit 1
}

# Determine month and year
$now = Get-Date
if (-not $Year) { $Year = $now.Year }
if (-not $Month) { $Month = $now.Month }

# Convert to 0-indexed month for API (0=January, 11=December)
$monthIndex = $Month - 1

if ($Verbose) {
    Write-Host "[VERBOSE] Target period: $Month/$Year (API month index: $monthIndex)" -ForegroundColor Gray
    Write-Host "[VERBOSE] Current date: $($now.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
}

$baseUrl = "https://ezpassmaineturnpike.com"

# Session cache file in .ezpass directory
$sessionCacheFile = Join-Path $configDir "cookies.xml"
$sessionMaxAge = 600 # 10 minutes in seconds

# Create new session
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Try to load cached cookies if they exist and are recent
$usedCachedSession = $false

if (Test-Path $sessionCacheFile) {
    $cacheAge = (Get-Date) - (Get-Item $sessionCacheFile).LastWriteTime

    if ($cacheAge.TotalSeconds -lt $sessionMaxAge) {
        try {
            $cachedData = Import-Clixml -Path $sessionCacheFile

            # Recreate cookies from cached data
            $uri = [System.Uri]::new($baseUrl)
            foreach ($cookieData in $cachedData) {
                # Create new Cookie object from cached properties
                $cookie = New-Object System.Net.Cookie
                $cookie.Name = $cookieData.Name
                $cookie.Value = $cookieData.Value
                $cookie.Domain = $cookieData.Domain
                $cookie.Path = $cookieData.Path

                # Add to session
                $session.Cookies.Add($uri, $cookie)
            }

            $usedCachedSession = $true

            if ($Verbose) {
                Write-Host "[VERBOSE] Loaded $($cachedData.Count) cached cookies (age: $([Math]::Round($cacheAge.TotalSeconds, 1))s)" -ForegroundColor Gray
            }

            Write-Host "Using cached session..." -ForegroundColor Green
        } catch {
            if ($Verbose) {
                Write-Host "[VERBOSE] Failed to load cached cookies: $_" -ForegroundColor Gray
            }
            $usedCachedSession = $false
        }
    } else {
        if ($Verbose) {
            Write-Host "[VERBOSE] Cached session too old ($([Math]::Round($cacheAge.TotalSeconds, 1))s), will re-login" -ForegroundColor Gray
        }
    }
}

# Only perform login if we're not using a cached session
if (-not $usedCachedSession) {
    Write-Host "Getting login page..." -ForegroundColor Cyan

# Get login page to retrieve CSRF token
try {
    $loginPageUrl = "$baseUrl/EZPass/Login.do"
    $loginPage = Invoke-WebRequest -Uri $loginPageUrl -SessionVariable session -UseBasicParsing
} catch {
    Write-Host "Error: Failed to get login page: $_" -ForegroundColor Red
    exit 2
}

# Check if the service is unavailable
if ($loginPage.Content -match 'currently unavailable|We''re Sorry') {
    Write-Host ""
    Write-Host "ERROR: Maine EZPass service is currently unavailable" -ForegroundColor Red
    Write-Host "The website shows: 'The online Maine Customer Service Center is currently unavailable.'" -ForegroundColor Yellow
    Write-Host "This is likely due to maintenance or technical issues on their end." -ForegroundColor Yellow
    Write-Host "Please try again later (in 30 minutes to a few hours)." -ForegroundColor Yellow
    Write-Host ""

    if ($Verbose) {
        Write-Host "[VERBOSE] Login page returned 'service unavailable' error" -ForegroundColor Gray
    }

    # Save error page for debugging
    $debugFile = "service-unavailable-debug.html"
    $loginPage.Content | Set-Content -Path $debugFile -Encoding UTF8

    if ($Verbose) {
        Write-Host "[VERBOSE] Error page saved to: $debugFile" -ForegroundColor Gray
    }

    exit 2
}

# Extract CSRF token from login page
$tokenMatch = [regex]::Match($loginPage.Content, 'name="(token_[^"]+)"\s+value="([^"]+)"')
if (-not $tokenMatch.Success) {
    Write-Host "Error: Could not find CSRF token on login page" -ForegroundColor Red

    if ($Verbose) {
        Write-Host "[VERBOSE] Login page status: $($loginPage.StatusCode)" -ForegroundColor Gray
        Write-Host "[VERBOSE] Login page content length: $($loginPage.Content.Length)" -ForegroundColor Gray
        Write-Host "[VERBOSE] First 500 chars of login page:" -ForegroundColor Gray
        Write-Host $loginPage.Content.Substring(0, [Math]::Min(500, $loginPage.Content.Length)) -ForegroundColor Gray
    }

    # Save login page for debugging
    $debugFile = "login-page-debug.html"
    $loginPage.Content | Set-Content -Path $debugFile -Encoding UTF8
    Write-Host "Login page saved to: $debugFile for debugging" -ForegroundColor Yellow

    exit 2
}

$tokenName = $tokenMatch.Groups[1].Value
$tokenValue = $tokenMatch.Groups[2].Value

Write-Host "Found CSRF token: $tokenName" -ForegroundColor Green

if ($Verbose) {
    Write-Host "[VERBOSE] CSRF token value: $($tokenValue.Substring(0, [Math]::Min(20, $tokenValue.Length)))..." -ForegroundColor Gray
}

Write-Host "Logging in as $Username..." -ForegroundColor Cyan

# Login
$loginUrl = "$baseUrl/EZPass/ProcessLogin.do"
$loginBody = @{
    $tokenName = $tokenValue
    username = $Username
    password = $Password
    cmdSubmit = 'Login'
}

try {
    $loginResponse = Invoke-WebRequest -Uri $loginUrl -Method Post -Body $loginBody -WebSession $session -UseBasicParsing
} catch {
    Write-Host "Error: Login failed: $_" -ForegroundColor Red
    exit 2
}

# Check if login was successful
if ($loginResponse.Content -match 'ProcessLogout\.do') {
    Write-Host "[OK] Login successful!" -ForegroundColor Green

    # Save cookies to cache
    try {
        $cookiesToCache = @()
        $uri = [System.Uri]::new($baseUrl)
        foreach ($cookie in $session.Cookies.GetCookies($uri)) {
            $cookiesToCache += $cookie
        }

        if ($cookiesToCache.Count -gt 0) {
            $cookiesToCache | Export-Clixml -Path $sessionCacheFile -Force
            Write-Host "Session cached for 10 minutes" -ForegroundColor Green

            if ($Verbose) {
                Write-Host "[VERBOSE] Cached $($cookiesToCache.Count) cookies to: $sessionCacheFile" -ForegroundColor Gray
            }
        } else {
            if ($Verbose) {
                Write-Host "[VERBOSE] No cookies to cache" -ForegroundColor Gray
            }
        }
    } catch {
        if ($Verbose) {
            Write-Host "[VERBOSE] Failed to cache cookies: $_" -ForegroundColor Gray
        }
    }
} elseif ($loginResponse.Content -match 'Account Already Logged In') {
    Write-Host ""
    Write-Host "WARNING: Account is already logged in from another session." -ForegroundColor Yellow
    Write-Host "The EZPass system only allows one active session at a time." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Waiting 90 seconds for the session to timeout, then retrying..." -ForegroundColor Cyan
    Start-Sleep -Seconds 90

    # Retry login
    Write-Host "Retrying login..." -ForegroundColor Cyan
    try {
        # Get new login page for fresh token
        $loginPage = Invoke-WebRequest -Uri $loginPageUrl -SessionVariable session -UseBasicParsing
        $tokenMatch = [regex]::Match($loginPage.Content, 'name="(token_[^"]+)"\s+value="([^"]+)"')
        if ($tokenMatch.Success) {
            $tokenName = $tokenMatch.Groups[1].Value
            $tokenValue = $tokenMatch.Groups[2].Value
            $loginBody = @{
                $tokenName = $tokenValue
                username = $Username
                password = $Password
                cmdSubmit = 'Login'
            }
            $loginResponse = Invoke-WebRequest -Uri $loginUrl -Method Post -Body $loginBody -WebSession $session -UseBasicParsing

            if ($loginResponse.Content -match 'ProcessLogout\.do') {
                Write-Host "[OK] Login successful on retry!" -ForegroundColor Green

                # Save cookies to cache
                try {
                    $cookiesToCache = @()
                    $uri = [System.Uri]::new($baseUrl)
                    foreach ($cookie in $session.Cookies.GetCookies($uri)) {
                        $cookiesToCache += $cookie
                    }

                    if ($cookiesToCache.Count -gt 0) {
                        $cookiesToCache | Export-Clixml -Path $sessionCacheFile -Force
                        Write-Host "Session cached for 10 minutes" -ForegroundColor Green

                        if ($Verbose) {
                            Write-Host "[VERBOSE] Cached $($cookiesToCache.Count) cookies to: $sessionCacheFile" -ForegroundColor Gray
                        }
                    } else {
                        if ($Verbose) {
                            Write-Host "[VERBOSE] No cookies to cache" -ForegroundColor Gray
                        }
                    }
                } catch {
                    if ($Verbose) {
                        Write-Host "[VERBOSE] Failed to cache cookies: $_" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "Error: Login still failed. Please wait 5 minutes and try again." -ForegroundColor Red
                exit 2
            }
        }
    } catch {
        Write-Host "Error: Retry failed: $_" -ForegroundColor Red
        exit 2
    }
} else {
    Write-Host "Error: Login failed - invalid credentials or unexpected response" -ForegroundColor Red
    exit 2
}
} # End of login block (if not using cached session)

# Fetch toll data as CSV (cleaner than HTML scraping)
Write-Host "Fetching toll data for $Month/$Year..." -ForegroundColor Cyan

$csvUrl = "$baseUrl/EZPass/DownloadPostedTolls.do?year=$Year&month=$monthIndex"

if ($Verbose) {
    Write-Host "[VERBOSE] CSV URL: $csvUrl" -ForegroundColor Gray
}

# Define headers for toll data request
$tollHeaders = @{
    'Referer' = "$baseUrl/EZPass/Summary.do"
    'Sec-Fetch-Site' = 'same-origin'
}

try {
    $csvResponse = Invoke-WebRequest -Uri $csvUrl -WebSession $session -Headers $tollHeaders -UseBasicParsing

    if ($Verbose) {
        Write-Host "[VERBOSE] CSV response status: $($csvResponse.StatusCode)" -ForegroundColor Gray
        Write-Host "[VERBOSE] CSV content length: $($csvResponse.Content.Length) bytes" -ForegroundColor Gray
    }
} catch {
    Write-Host "Error: Failed to fetch toll data: $_" -ForegroundColor Red
    exit 2
}

# Parse CSV data (much cleaner than HTML!)
$csvData = $csvResponse.Content

# Save CSV to file if requested
if ($DownloadFile) {
    $csvFileName = "toll-data-$Month-$Year.csv"
    $csvData | Set-Content -Path $csvFileName -Encoding UTF8
    Write-Host "[OK] CSV data saved to: $csvFileName" -ForegroundColor Green

    if ($Verbose) {
        Write-Host "[VERBOSE] First 200 chars of CSV:" -ForegroundColor Gray
        Write-Host $csvData.Substring(0, [Math]::Min(200, $csvData.Length)) -ForegroundColor Gray
    }
}

if ($Verbose) {
    Write-Host "[VERBOSE] Parsing CSV data..." -ForegroundColor Gray
}

# Use ConvertFrom-Csv to properly handle quoted comma-separated values
$tollRecords = $csvData | ConvertFrom-Csv

if ($Verbose) {
    Write-Host "[VERBOSE] Parsed $($tollRecords.Count) CSV records" -ForegroundColor Gray
}

$totalTolls = 0
$discountEligible = 0
$tollDetails = @()
$totalAmount = 0.0

# Process each record
foreach ($record in $tollRecords) {
    # Extract fields from CSV columns
    $postedDate = $record.'Posting Date'
    $tag = $record.'Tag/Vehicle Reg.'
    $transDate = $record.'Transaction Date'
    $transTime = $record.'Transaction Time'
    $facility = $record.'Facility'
    $entry = $record.'Entry/Barrier Plaza'
    $exitPlaza = $record.'Exit Plaza'
    $amountStr = $record.'Toll'
    $eligibleText = $record.'Discount Eligible?'

    # Skip non-data rows (footer text, empty rows)
    if ([string]::IsNullOrWhiteSpace($transDate) -or [string]::IsNullOrWhiteSpace($amountStr)) {
        if ($Verbose) {
            Write-Host "[VERBOSE] Skipping non-data row: $($record.'Posting Date')" -ForegroundColor DarkGray
        }
        continue
    }

    $totalTolls++

    # Combine date and time
    $transDateTime = "$transDate $transTime"

    # Parse amount - handle both "$0.80" and "$.80" formats
    $amount = 0.0
    if ($amountStr -match '\$?(\d*\.?\d+)') {
        $amountValue = $matches[1]
        # If it starts with a decimal point, prepend "0"
        if ($amountValue.StartsWith('.')) {
            $amountValue = "0$amountValue"
        }
        $amount = [decimal]$amountValue
    }

    if ($eligibleText -eq 'Yes') {
        $discountEligible++
        $totalAmount += $amount
    }

    if ($Verbose) {
        Write-Host "[VERBOSE] Toll #$totalTolls : $transDateTime | $facility | $amountStr -> `$$amount | Eligible: $eligibleText" -ForegroundColor Gray
    }

    $tollDetails += [PSCustomObject]@{
        PostedDate = $postedDate
        TransDateTime = $transDateTime
        Facility = $facility
        Entry = $entry
        Exit = $exitPlaza
        Amount = $amount
        AmountFormatted = $amountStr
        DiscountEligible = $eligibleText
    }
}

if ($Verbose) {
    Write-Host "[VERBOSE] Parsing complete: $totalTolls total, $discountEligible eligible, Total amount: `$$totalAmount" -ForegroundColor Gray
}

# Helper function to output text (capturable for email)
function Write-Output-Line {
    param([string]$Text, [string]$Color = "White")
    if ($EmailOutput) {
        Write-Output $Text
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}

# SMS Format Output (compact for text messages)
if ($SmsFormat) {
    # Calculate estimation if in current month
    $estimatedTotal = $discountEligible
    if ($Estimate -and $Year -eq $now.Year -and $Month -eq $now.Month) {
        $currentDay = $now.Day
        $daysInMonth = [DateTime]::DaysInMonth($Year, $Month)
        if ($currentDay -gt 0) {
            $dailyAverage = $discountEligible / $currentDay
            $estimatedTotal = $dailyAverage * $daysInMonth
        }
    }

    # Function to generate progress bar
    function Get-ProgressBar {
        param([int]$current, [int]$target = 40, [int]$width = 8)
        $filled = [Math]::Min([Math]::Floor(($current / $target) * $width), $width)
        $empty = $width - $filled
        return ('[' + ('=' * $filled) + ('-' * $empty) + ']')
    }

    # Determine tier
    $tollCount = if ($Estimate) { [int]$estimatedTotal } else { $discountEligible }
    $tier = if ($tollCount -ge 40) { "Gold" } elseif ($tollCount -ge 30) { "Bronze" } else { "None" }

    # Calculate total toll amount for savings
    $totalAmount = 0.0
    foreach ($toll in $tollDetails) {
        if ($toll.DiscountEligible -eq 'Yes') {
            $totalAmount += $toll.Amount
        }
    }

    # Generate SMS output
    $progressBar = Get-ProgressBar -current $tollCount -target 40

    if ($tier -eq "Gold") {
        $savings = $totalAmount * 0.40
        Write-Output "EZPass: $progressBar $tollCount/40"
        Write-Output "Gold 40% | -`$$([Math]::Round($savings, 2))/mo"
    }
    elseif ($tier -eq "Bronze") {
        $needed = 40 - $tollCount
        $additionalSavings = $totalAmount * 0.20  # Additional savings from going 20% to 40%
        Write-Output "EZPass: $progressBar $tollCount/40"
        Write-Output "Bronze 20% | $needed→Gold +`$$([Math]::Round($additionalSavings, 2))"
    }
    else {
        $potentialSavings = $totalAmount * 0.40
        $estDisplay = if ($Estimate) { "Est $([Math]::Round($estimatedTotal, 0))" } else { "$tollCount" }
        Write-Output "EZPass: $progressBar $tollCount/40"
        Write-Output "$estDisplay → Gold -`$$([Math]::Round($potentialSavings, 2))"
    }

    # Set exit code based on tier
    if ($tier -eq "Gold") {
        exit 1
    } elseif ($tier -eq "Bronze") {
        exit 2
    } else {
        exit 3
    }
}

# Display results
Write-Output-Line ""
Write-Output-Line ("=" * 60) "Cyan"
Write-Output-Line "TOLL REPORT FOR $Month/$Year" "White"
Write-Output-Line ("=" * 60) "Cyan"
Write-Output-Line "Total tolls posted: $totalTolls"
Write-Output-Line "Discount-eligible tolls: $discountEligible"
Write-Output-Line ("=" * 60) "Cyan"

# Function to determine discount tier
function Get-DiscountTier {
    param([int]$tollCount)

    if ($tollCount -lt 30) {
        return @{
            Tier = "None"
            Discount = "0%"
            Color = "Red"
            Message = "No discount"
        }
    } elseif ($tollCount -lt 40) {
        return @{
            Tier = "Bronze"
            Discount = "20%"
            Color = "Yellow"
            Message = "20% discount"
        }
    } else {
        return @{
            Tier = "Gold"
            Discount = "40%"
            Color = "Green"
            Message = "40% discount - Maximum savings!"
        }
    }
}

# Estimate if requested and checking current month
$estimatedTotal = $discountEligible
if ($Estimate -and $Year -eq $now.Year -and $Month -eq $now.Month) {
    $currentDay = $now.Day
    $daysInMonth = [DateTime]::DaysInMonth($Year, $Month)

    if ($currentDay -gt 0) {
        $dailyAverage = $discountEligible / $currentDay
        $estimatedTotal = $dailyAverage * $daysInMonth

        if ($Verbose) {
            Write-Host "[VERBOSE] Estimation: Day $currentDay of $daysInMonth | Daily avg: $([Math]::Round($dailyAverage, 2)) | Projected: $([Math]::Round($estimatedTotal, 1))" -ForegroundColor Gray
        }

        Write-Output-Line ""
        Write-Output-Line "Current day: $currentDay of $daysInMonth"
        Write-Output-Line ("Estimated month-end discount-eligible tolls: {0:N1}" -f $estimatedTotal)
        Write-Output-Line ("=" * 60) "Cyan"

        $tier = Get-DiscountTier -tollCount ([int]$estimatedTotal)

        Write-Output-Line ""
        Write-Output-Line (">> Projected Discount Tier: {0}" -f $tier.Tier) $tier.Color
        Write-Output-Line ("   {0}" -f $tier.Message) $tier.Color
        Write-Output-Line ("   Estimated: {0:N1} tolls" -f $estimatedTotal) $tier.Color

        # Show what's needed for next tier
        if ($estimatedTotal -lt 30) {
            $needed = 30 - $estimatedTotal
            Write-Output-Line ""
            Write-Output-Line ("TIP: Need {0:N1} more tolls for 20% discount" -f $needed) "Cyan"
        } elseif ($estimatedTotal -lt 40) {
            $needed = 40 - $estimatedTotal
            Write-Output-Line ""
            Write-Output-Line ("TIP: Need {0:N1} more tolls for 40% discount" -f $needed) "Cyan"
            $under = 40 - $estimatedTotal
            Write-Output-Line ("WARNING: Or reduce by {0:N1} tolls to drop to no discount tier" -f ($estimatedTotal - 29)) "Yellow"
        }
    }
} else {
    # For completed months
    $tier = Get-DiscountTier -tollCount $discountEligible

    Write-Output-Line ""
    Write-Output-Line (">> Discount Tier: {0}" -f $tier.Tier) $tier.Color
    Write-Output-Line ("   {0}" -f $tier.Message) $tier.Color
    Write-Output-Line ("   Total: $discountEligible tolls") $tier.Color
}

# Show detailed toll information with discounted amounts
if ($tollDetails.Count -gt 0) {
    Write-Output-Line ""
    Write-Output-Line ("=" * 70) "Cyan"
    Write-Output-Line "TOLL TRANSACTIONS THIS MONTH" "White"
    Write-Output-Line ("=" * 70) "Cyan"

    # Get projected tier for discount calculation
    $projectedTier = if ($Estimate -and $estimatedTotal -ge 0) {
        Get-DiscountTier -tollCount ([int]$estimatedTotal)
    } else {
        Get-DiscountTier -tollCount $discountEligible
    }

    # Calculate discount percentage
    $discountPct = 0.0
    if ($projectedTier.Tier -eq 'Gold') {
        $discountPct = 0.40
    } elseif ($projectedTier.Tier -eq 'Bronze') {
        $discountPct = 0.20
    }

    $i = 1
    $totalSavings = 0.0
    foreach ($toll in $tollDetails) {
        $discountedAmount = $toll.Amount
        $savings = 0.0

        if ($toll.DiscountEligible -eq 'Yes' -and $discountPct -gt 0) {
            $discountedAmount = $toll.Amount * (1 - $discountPct)
            $savings = $toll.Amount - $discountedAmount
            $totalSavings += $savings
        }

        Write-Output-Line ""
        Write-Output-Line "$i. $($toll.TransDateTime) - $($toll.Facility):"
        Write-Output-Line "   From $($toll.Entry) to $($toll.Exit)"

        if ($toll.DiscountEligible -eq 'Yes' -and $discountPct -gt 0) {
            Write-Output-Line ("   Toll: `${0:N2} -> `${1:N2} (save `${2:N2} with {3}% discount)" -f $toll.Amount, $discountedAmount, $savings, ($discountPct * 100))
        } elseif ($toll.DiscountEligible -eq 'Yes') {
            Write-Output-Line ("   Toll: `${0:N2} [Eligible - no discount yet]" -f $toll.Amount)
        } else {
            Write-Output-Line ("   Toll: `${0:N2} [Not Eligible]" -f $toll.Amount)
        }
        $i++
    }

    if ($totalSavings -gt 0) {
        Write-Output-Line ""
        Write-Output-Line ("Total Savings This Month: `${0:N2}" -f $totalSavings) "Green"
    }

    Write-Output-Line ""
    Write-Output-Line ("=" * 70) "Cyan"
} elseif ($totalTolls -eq 0) {
    Write-Output-Line ""
    Write-Output-Line "No tolls posted this month yet." "Gray"
    Write-Output-Line ""
}

# Determine exit code based on discount tier
$exitCode = 0
if ($Estimate -and $estimatedTotal -ge 0) {
    $finalCount = [int]$estimatedTotal
} else {
    $finalCount = $discountEligible
}

if ($finalCount -lt 30) {
    $exitCode = 3  # No discount tier
} elseif ($finalCount -lt 40) {
    $exitCode = 2  # 20% discount tier
} else {
    $exitCode = 1  # 40% discount tier (maximum)
}

if ($Verbose) {
    Write-Host "[VERBOSE] Final count: $finalCount | Exit code: $exitCode (3=None, 2=Bronze, 1=Gold)" -ForegroundColor Gray
}

exit $exitCode
