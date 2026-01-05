<#
.SYNOPSIS
Setup script for Maine EZPass Toll Monitor

.DESCRIPTION
Interactive setup to configure EZPass credentials and optional email notifications.
All credentials are encrypted and stored securely in your user profile.
#>

Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Maine EZPass Toll Monitor - Setup" -ForegroundColor White
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Secure config location
$configDir = Join-Path $env:USERPROFILE ".ezpass"
$configFile = Join-Path $configDir "config.xml"

# Check if config already exists
$existingConfig = $null
if (Test-Path $configFile) {
    Write-Host "WARNING: Configuration already exists!" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to update it? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }

    # Load existing config to preserve settings we're not updating
    try {
        $existingConfig = Import-Clixml -Path $configFile
    } catch {
        Write-Warning "Could not load existing config: $_"
    }
}

# Initialize config structure
if ($existingConfig) {
    $config = $existingConfig
} else {
    $config = @{
        EZPass = @{}
        Email = @{}
    }
}

# ============================================================
# EZPass Credentials
# ============================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "EZPass Credentials" -ForegroundColor White
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "Please enter your Maine EZPass credentials:" -ForegroundColor Cyan
Write-Host "(These will be encrypted and stored in: $configFile)" -ForegroundColor Gray
Write-Host ""

$username = Read-Host "EZPass Username"
$passwordSecure = Read-Host "EZPass Password" -AsSecureString

if (-not $username -or $passwordSecure.Length -eq 0) {
    Write-Host "Error: Username and password cannot be empty" -ForegroundColor Red
    exit 1
}

# Save EZPass credentials
$config.EZPass.Username = $username
$config.EZPass.Password = $passwordSecure

Write-Host ""
Write-Host "[OK] EZPass credentials saved" -ForegroundColor Green

# ============================================================
# Email Notifications (Optional)
# ============================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Email Notifications (Optional)" -ForegroundColor White
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "Would you like to set up email notifications?" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Yes - Configure email notifications" -ForegroundColor White
Write-Host "  2. No - Skip email setup" -ForegroundColor White
Write-Host ""

$emailChoice = Read-Host "Enter choice (1-2)"

if ($emailChoice -eq "1") {
    # Provider selection
    Write-Host ""
    Write-Host "Select your email provider:" -ForegroundColor Cyan
    Write-Host "  1. Gmail (recommended)" -ForegroundColor White
    Write-Host "  2. Outlook/Hotmail" -ForegroundColor White
    Write-Host "  3. Yahoo" -ForegroundColor White
    Write-Host "  4. Other (custom SMTP)" -ForegroundColor White
    Write-Host ""

    $provider = Read-Host "Enter choice (1-4)"

    $smtpServer = ""
    $port = 587

    switch ($provider) {
        "1" {
            $smtpServer = "smtp.gmail.com"
            Write-Host ""
            Write-Host "Gmail Setup Instructions:" -ForegroundColor Yellow
            Write-Host "1. Enable 2-Factor Authentication on your Google account" -ForegroundColor Gray
            Write-Host "2. Go to: https://myaccount.google.com/apppasswords" -ForegroundColor Gray
            Write-Host "3. Create an App Password for 'Mail' on 'Windows Computer'" -ForegroundColor Gray
            Write-Host "4. Use the 16-character password below (NOT your Gmail password)" -ForegroundColor Gray
            Write-Host ""
        }
        "2" {
            $smtpServer = "smtp.office365.com"
            Write-Host ""
            Write-Host "Outlook/Hotmail: Use your regular account password" -ForegroundColor Yellow
            Write-Host ""
        }
        "3" {
            $smtpServer = "smtp.mail.yahoo.com"
            Write-Host ""
            Write-Host "Yahoo Setup Instructions:" -ForegroundColor Yellow
            Write-Host "1. Go to Yahoo Account Security settings" -ForegroundColor Gray
            Write-Host "2. Generate an App Password" -ForegroundColor Gray
            Write-Host "3. Use the app password below (NOT your Yahoo password)" -ForegroundColor Gray
            Write-Host ""
        }
        "4" {
            Write-Host ""
            $smtpServer = Read-Host "SMTP Server address"
            $portInput = Read-Host "SMTP Port (default: 587)"
            if ($portInput) { $port = [int]$portInput }
        }
        default {
            Write-Host "Invalid choice, skipping email setup" -ForegroundColor Yellow
            $emailChoice = "2"
        }
    }

    if ($emailChoice -eq "1") {
        # Get email addresses
        Write-Host ""
        $fromEmail = Read-Host "Your email address"
        $toEmail = Read-Host "Send notifications to (press Enter for same address)"

        if (-not $toEmail) {
            $toEmail = $fromEmail
        }

        # Get password
        Write-Host ""
        $emailPasswordSecure = Read-Host "Email password (or App Password)" -AsSecureString

        # Optional: selective notifications
        Write-Host ""
        Write-Host "Notification preferences:" -ForegroundColor Cyan
        Write-Host "  1. All tiers (always notify)" -ForegroundColor White
        Write-Host "  2. Only Bronze + Gold (20% and 40% discount tiers)" -ForegroundColor White
        Write-Host "  3. Only Gold (40% discount tier only)" -ForegroundColor White
        Write-Host "  4. Only when no discount" -ForegroundColor White
        Write-Host ""

        $tierChoice = Read-Host "Enter choice (1-4, default: 1)"

        $onlyAlertOnTiers = switch ($tierChoice) {
            "2" { "Bronze,Gold" }
            "3" { "Gold" }
            "4" { "None" }
            default { "" }
        }

        # Save email configuration
        $config.Email.SmtpServer = $smtpServer
        $config.Email.Port = $port
        $config.Email.From = $fromEmail
        $config.Email.To = $toEmail
        $config.Email.Username = $fromEmail
        $config.Email.Password = $emailPasswordSecure
        $config.Email.UseSsl = $true
        $config.Email.OnlyAlertOnTiers = $onlyAlertOnTiers

        Write-Host ""
        Write-Host "[OK] Email configuration saved" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "Email setup skipped" -ForegroundColor Gray
}

# ============================================================
# Save Configuration
# ============================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Saving configuration..." -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan

# Create config directory if it doesn't exist
if (-not (Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory -Force | Out-Null
}

# Save secure configuration
try {
    $config | Export-Clixml -Path $configFile -Force

    Write-Host ""
    Write-Host "[OK] Configuration saved to: $configFile" -ForegroundColor Green
    Write-Host ""
    Write-Host "Security Note:" -ForegroundColor Yellow
    Write-Host "Credentials are encrypted using Windows Data Protection API (DPAPI)" -ForegroundColor Gray
    Write-Host "Only your Windows user account can decrypt them" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "Error saving configuration: $_" -ForegroundColor Red
    exit 1
}

# ============================================================
# Test Connection
# ============================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Testing EZPass connection..." -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

try {
    & ".\check-tolls.ps1" -Estimate

    if ($LASTEXITCODE -eq 1 -or $LASTEXITCODE -eq 2 -or $LASTEXITCODE -eq 3) {
        Write-Host ""
        Write-Host "=" * 70 -ForegroundColor Green
        Write-Host "[OK] EZPass connection successful!" -ForegroundColor Green
        Write-Host "=" * 70 -ForegroundColor Green

        # Test email if configured
        if ($emailChoice -eq "1") {
            Write-Host ""
            $testEmail = Read-Host "Would you like to send a test email? (yes/no)"

            if ($testEmail -eq "yes") {
                Write-Host ""
                Write-Host "Sending test email..." -ForegroundColor Cyan

                try {
                    & ".\notify-email.ps1"

                    Write-Host ""
                    Write-Host "[OK] Test email sent!" -ForegroundColor Green
                    Write-Host "Check your inbox at: $toEmail" -ForegroundColor Cyan
                } catch {
                    Write-Host ""
                    Write-Host "WARNING: Test email failed" -ForegroundColor Yellow
                    Write-Host "Error: $_" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Common issues:" -ForegroundColor Yellow
                    Write-Host "  - Gmail: Make sure you created an App Password (not regular password)" -ForegroundColor Gray
                    Write-Host "  - Check your email address and password are correct" -ForegroundColor Gray
                    Write-Host "  - Try running: .\notify-email.ps1 to test again" -ForegroundColor Gray
                }
            }
        }

        Write-Host ""
        Write-Host "=" * 70 -ForegroundColor Green
        Write-Host "Setup Complete!" -ForegroundColor Green
        Write-Host "=" * 70 -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now run:" -ForegroundColor Cyan
        Write-Host "  .\check-tolls.ps1 -Estimate       # Check your tolls" -ForegroundColor White

        if ($emailChoice -eq "1") {
            Write-Host "  .\notify-email.ps1                # Send email notification" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "See README.md for automation instructions" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "WARNING: Setup completed but there was an issue with the test." -ForegroundColor Yellow
        Write-Host "Please check your credentials and try again." -ForegroundColor Yellow
    }

} catch {
    Write-Host "Error testing connection: $_" -ForegroundColor Red
    Write-Host "Please check your credentials and internet connection." -ForegroundColor Yellow
}

Write-Host ""
