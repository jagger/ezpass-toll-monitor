# Email notification wrapper for Maine EZPass Toll Monitor

# Secure config location in user home directory
$configDir = Join-Path $env:USERPROFILE ".ezpass"
$configFile = Join-Path $configDir "config.xml"

# Load secure config
if (-not (Test-Path $configFile)) {
    Write-Host "Error: Configuration not found" -ForegroundColor Red
    Write-Host "Run .\setup.ps1 first to configure your settings" -ForegroundColor Yellow
    exit 1
}

try {
    $secureConfig = Import-Clixml -Path $configFile
} catch {
    Write-Host "Error loading config: $_" -ForegroundColor Red
    exit 1
}

# Check if email is configured
if (-not $secureConfig.Email -or -not $secureConfig.Email.SmtpServer) {
    Write-Host "Error: Email not configured" -ForegroundColor Red
    Write-Host "Run .\setup.ps1 and configure email settings" -ForegroundColor Yellow
    exit 1
}

# Extract email config
$emailConfig = $secureConfig.Email

# Run the toll check and capture output
Write-Host "Running toll check..." -ForegroundColor Cyan
$output = & ".\check-tolls.ps1" -Estimate -EmailOutput
$exitCode = $LASTEXITCODE

# Convert output to string for email
$bodyText = ($output | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($bodyText)) {
    $bodyText = "Toll check completed with exit code: $exitCode`nNo toll data retrieved."
}

# Also display to console
Write-Host ""
Write-Host $bodyText
Write-Host ""

# Check if toll check actually succeeded or failed
$tollCheckFailed = $false
$serviceUnavailable = $false

if ($bodyText -match "currently unavailable|service is currently unavailable") {
    $tollCheckFailed = $true
    $serviceUnavailable = $true
    Write-Host ""
    Write-Host "WARNING: EZPass service unavailable - sending notification" -ForegroundColor Yellow
} elseif ($bodyText -match "No toll data retrieved|Error:|Login failed|Login still failed") {
    $tollCheckFailed = $true
    Write-Host ""
    Write-Host "WARNING: Toll check failed - sending error notification" -ForegroundColor Yellow
}

# Determine discount tier from exit code
$tierName = switch ($exitCode) {
    3 { "None" }
    2 { "Bronze" }
    1 { "Gold" }
    default { "Unknown" }
}

# Check if we should send notification for this tier (skip check if failed)
$shouldNotify = $true
if (-not $tollCheckFailed -and $emailConfig.OnlyAlertOnTiers) {
    $alertTiers = $emailConfig.OnlyAlertOnTiers -split ','
    $shouldNotify = $alertTiers -contains $tierName
}

if (-not $shouldNotify) {
    Write-Host ""
    Write-Host "INFO: No notification sent (tier '$tierName' not in alert list)" -ForegroundColor Gray
    exit 0
}

# Calculate potential savings if not at max discount
$potentialSavings = 0.0
if ($bodyText -match 'Total tolls posted:\s*(\d+)') {
    $totalTolls = [int]$matches[1]
}
if ($bodyText -match 'Discount-eligible tolls:\s*(\d+)') {
    $eligibleTolls = [int]$matches[1]
}

# Extract total amount from body
$totalAmount = 0.0
if ($bodyText -match 'Toll:\s*\$([0-9.]+)') {
    # Sum all toll amounts
    $tollAmounts = [regex]::Matches($bodyText, 'Toll:\s*\$([0-9.]+)')
    foreach ($match in $tollAmounts) {
        $totalAmount += [decimal]$match.Groups[1].Value
    }
}

# Determine email subject
if ($tollCheckFailed) {
    # Error occurred - use error subject
    if ($serviceUnavailable) {
        $subject = "EZPass Monitor - Service Currently Unavailable"
    } else {
        $subject = "EZPass Monitor Error - Failed to retrieve toll data"
    }
} else {
    # Calculate max savings (40% discount)
    if ($exitCode -eq 3) {
        # No discount tier - show potential savings with Gold tier
        $maxSavings = $totalAmount * 0.40
        $subject = "EZPass Alert: No Discount - Potential `$$([math]::Round($maxSavings, 2)) savings with Gold"
    } elseif ($exitCode -eq 2) {
        # Bronze tier - show additional savings with Gold tier
        $currentSavings = $totalAmount * 0.20
        $maxSavings = $totalAmount * 0.40
        $additionalSavings = $maxSavings - $currentSavings
        $subject = "EZPass Alert: Bronze (20%) - `$$([math]::Round($additionalSavings, 2)) more with Gold"
    } elseif ($exitCode -eq 1) {
        # Gold tier - maximum discount achieved!
        $maxSavings = $totalAmount * 0.40
        $subject = "EZPass Alert: Gold (40%) - Saving `$$([math]::Round($maxSavings, 2)) this month!"
    } else {
        $subject = 'EZPass Monitor Error - Unknown status'
    }
}

# Send email
try {
    Write-Host ""
    Write-Host "Sending email notification..." -ForegroundColor Cyan
    Write-Host "  From: $($emailConfig.From)" -ForegroundColor Gray
    Write-Host "  To: $($emailConfig.To)" -ForegroundColor Gray
    Write-Host "  Subject: $subject" -ForegroundColor Gray

    # Create credential if password provided
    $credential = $null
    if ($emailConfig.Password) {
        $credential = New-Object -TypeName PSCredential -ArgumentList $emailConfig.Username, $emailConfig.Password
    }

    # Build email parameters
    $emailParams = @{
        From = $emailConfig.From
        To = $emailConfig.To -split ','
        Subject = $subject
        Body = $bodyText
        SmtpServer = $emailConfig.SmtpServer
        Port = $emailConfig.Port
    }

    if ($emailConfig.UseSsl) {
        $emailParams.UseSsl = $true
    }

    if ($credential) {
        $emailParams.Credential = $credential
    }

    Send-MailMessage @emailParams

    Write-Host "[OK] Email sent successfully!" -ForegroundColor Green

} catch {
    Write-Host "Error sending email: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  - Gmail users: Enable 2FA and create an App Password" -ForegroundColor Gray
    Write-Host "  - Outlook/Hotmail: smtp.office365.com, port 587" -ForegroundColor Gray
    Write-Host "  - Yahoo: smtp.mail.yahoo.com, port 587" -ForegroundColor Gray
    exit 1
}

exit 0
