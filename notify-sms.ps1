# SMS notification wrapper for Maine EZPass Toll Monitor

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

# Check if SMS is configured
if (-not $secureConfig.SMS -or -not $secureConfig.SMS.To) {
    Write-Host "Error: SMS not configured" -ForegroundColor Red
    Write-Host "Run .\setup.ps1 and configure SMS settings" -ForegroundColor Yellow
    exit 1
}

# Extract SMS config
$smsConfig = $secureConfig.SMS
$emailConfig = $secureConfig.Email

# Run the toll check with SMS format
Write-Host "Running toll check..." -ForegroundColor Cyan
$output = & ".\check-tolls.ps1" -Estimate -SmsFormat
$exitCode = $LASTEXITCODE

# Convert output to string for SMS
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
    Write-Host "WARNING: EZPass service unavailable - sending SMS notification" -ForegroundColor Yellow
} elseif ($bodyText -match "No toll data retrieved|Error:|Login failed|Login still failed") {
    $tollCheckFailed = $true
    Write-Host ""
    Write-Host "WARNING: Toll check failed - sending error SMS notification" -ForegroundColor Yellow
}

# Determine if we should send notification based on tier filter
$shouldNotify = $true
if (-not $tollCheckFailed -and $smsConfig.OnlyAlertOnTiers) {
    $tierName = switch ($exitCode) {
        3 { "None" }
        2 { "Bronze" }
        1 { "Gold" }
        default { "Unknown" }
    }

    $alertTiers = $smsConfig.OnlyAlertOnTiers -split ','
    $shouldNotify = $alertTiers -contains $tierName
}

if (-not $shouldNotify) {
    Write-Host ""
    Write-Host "INFO: No SMS sent (tier not in alert list)" -ForegroundColor Gray
    exit 0
}

# Prepare SMS subject (some carriers show this)
if ($tollCheckFailed) {
    if ($serviceUnavailable) {
        $subject = "EZPass: Service Down"
    } else {
        $subject = "EZPass: Error"
    }
} else {
    $subject = "EZPass Status"
}

# Send SMS via email-to-SMS gateway
try {
    Write-Host ""
    Write-Host "Sending SMS notification..." -ForegroundColor Cyan
    Write-Host "  To: $($smsConfig.To)" -ForegroundColor Gray
    Write-Host "  Via: $($emailConfig.SmtpServer)" -ForegroundColor Gray

    # Create credential if password provided
    $credential = $null
    if ($emailConfig.Password) {
        $credential = New-Object -TypeName PSCredential -ArgumentList $emailConfig.Username, $emailConfig.Password
    }

    # Build email parameters for SMS gateway
    $emailParams = @{
        From = $emailConfig.From
        To = $smsConfig.To
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

    Write-Host "[OK] SMS sent successfully!" -ForegroundColor Green

} catch {
    Write-Host "Error sending SMS: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  - Check your carrier's email-to-SMS gateway address" -ForegroundColor Gray
    Write-Host "  - Ensure email credentials are configured (uses Email config)" -ForegroundColor Gray
    Write-Host "  - Some carriers may block email-to-SMS from certain providers" -ForegroundColor Gray
    exit 1
}

exit 0
