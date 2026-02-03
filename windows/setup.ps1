<#
.SYNOPSIS
Setup script for Maine EZPass Toll Monitor

.DESCRIPTION
Interactive setup to configure EZPass credentials and optional email/SMS notifications.
All credentials are encrypted and stored securely in your user profile.
#>

Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Maine EZPass Toll Monitor - Setup" -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

# Secure config location
$configDir = Join-Path $env:USERPROFILE ".ezpass"
$configFile = Join-Path $configDir "config.xml"

# Check if config already exists
$existingConfig = $null
$isUpdate = $false
if (Test-Path $configFile) {
    Write-Host "Configuration found!" -ForegroundColor Green
    Write-Host "Current settings will be shown (passwords hidden)" -ForegroundColor Gray
    Write-Host "Press Enter to keep existing values, or type new values to update" -ForegroundColor Gray
    Write-Host ""

    $continue = Read-Host "Continue with update? (yes/no)"
    if ($continue -ne "yes") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }

    # Load existing config
    try {
        $existingConfig = Import-Clixml -Path $configFile
        $isUpdate = $true
    } catch {
        Write-Warning "Could not load existing config: $_"
        $existingConfig = $null
    }
}

# Initialize config structure
if ($existingConfig) {
    $config = $existingConfig
} else {
    $config = @{
        EZPass = @{}
        Email = @{}
        SMS = @{}
    }
}

# ============================================================
# EZPass Credentials
# ============================================================
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "EZPass Credentials" -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

if ($isUpdate -and $config.EZPass.Username) {
    Write-Host "Current username: $($config.EZPass.Username)" -ForegroundColor Gray
    Write-Host ""
    $usernameInput = Read-Host "EZPass Username (press Enter to keep current)"
    if ([string]::IsNullOrWhiteSpace($usernameInput)) {
        $username = $config.EZPass.Username
        Write-Host "Keeping existing username" -ForegroundColor Gray
    } else {
        $username = $usernameInput
    }

    Write-Host ""
    $updatePassword = Read-Host "Update password? (yes/no)"
    if ($updatePassword -eq "yes") {
        $passwordSecure = Read-Host "EZPass Password" -AsSecureString
    } else {
        $passwordSecure = $config.EZPass.Password
        Write-Host "Keeping existing password" -ForegroundColor Gray
    }
} else {
    Write-Host "Please enter your Maine EZPass credentials:" -ForegroundColor Cyan
    Write-Host "(These will be encrypted and stored in: $configFile)" -ForegroundColor Gray
    Write-Host ""

    $username = Read-Host "EZPass Username"
    $passwordSecure = Read-Host "EZPass Password" -AsSecureString
}

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
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Email Notifications (Optional)" -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

$emailChoice = "2"
if ($isUpdate -and $config.Email.SmtpServer) {
    Write-Host "Email is currently configured:" -ForegroundColor Green
    Write-Host "  From: $($config.Email.From)" -ForegroundColor Gray
    Write-Host "  To: $($config.Email.To)" -ForegroundColor Gray
    Write-Host "  SMTP: $($config.Email.SmtpServer):$($config.Email.Port)" -ForegroundColor Gray
    Write-Host ""
    $updateEmail = Read-Host "Update email configuration? (yes/no/skip)"

    if ($updateEmail -eq "skip") {
        $emailChoice = "1"  # Keep existing
        Write-Host "Keeping existing email configuration" -ForegroundColor Gray
    } elseif ($updateEmail -ne "yes") {
        $emailChoice = "2"  # Skip
    } else {
        $emailChoice = "1"  # Reconfigure
    }
} else {
    Write-Host "Would you like to set up email notifications?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Yes - Configure email notifications" -ForegroundColor White
    Write-Host "  2. No - Skip email setup" -ForegroundColor White
    Write-Host ""

    $emailChoice = Read-Host "Enter choice (1-2)"
}

if ($emailChoice -eq "1" -and $updateEmail -ne "skip") {
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
    if ($emailChoice -ne "1") {
        Write-Host ""
        Write-Host "Email setup skipped" -ForegroundColor Gray
    }
}

# ============================================================
# SMS Notifications (Optional)
# ============================================================
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "SMS Notifications (Optional)" -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

$smsChoice = "2"
if ($isUpdate -and $config.SMS.To) {
    Write-Host "SMS is currently configured:" -ForegroundColor Green
    Write-Host "  To: $($config.SMS.To)" -ForegroundColor Gray
    Write-Host "  Carrier: $($config.SMS.Carrier)" -ForegroundColor Gray
    Write-Host ""
    $updateSms = Read-Host "Update SMS configuration? (yes/no/skip)"

    if ($updateSms -eq "skip") {
        $smsChoice = "1"  # Keep existing
        Write-Host "Keeping existing SMS configuration" -ForegroundColor Gray
    } elseif ($updateSms -ne "yes") {
        $smsChoice = "2"  # Skip
    } else {
        $smsChoice = "1"  # Reconfigure
    }
} else {
    if ($config.Email.SmtpServer) {
        Write-Host "Would you like to set up SMS notifications?" -ForegroundColor Cyan
        Write-Host "Note: SMS uses email-to-SMS gateways (requires email config above)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  1. Yes - Configure SMS notifications" -ForegroundColor White
        Write-Host "  2. No - Skip SMS setup" -ForegroundColor White
        Write-Host ""

        $smsChoice = Read-Host "Enter choice (1-2)"
    } else {
        Write-Host "SMS requires email configuration (uses SMTP for email-to-SMS gateways)" -ForegroundColor Yellow
        Write-Host "Email was not configured, skipping SMS setup" -ForegroundColor Gray
        $smsChoice = "2"
    }
}

if ($smsChoice -eq "1" -and $updateSms -ne "skip" -and $config.Email.SmtpServer) {
    # Carrier selection
    Write-Host ""
    Write-Host "Select your mobile carrier:" -ForegroundColor Cyan
    Write-Host "  1. Verizon" -ForegroundColor White
    Write-Host "  2. AT&T" -ForegroundColor White
    Write-Host "  3. T-Mobile" -ForegroundColor White
    Write-Host "  4. Sprint" -ForegroundColor White
    Write-Host "  5. Other (enter custom gateway)" -ForegroundColor White
    Write-Host ""

    $carrier = Read-Host "Enter choice (1-5)"

    $smsGateway = ""
    switch ($carrier) {
        "1" { $smsGateway = "@vtext.com" }
        "2" { $smsGateway = "@txt.att.net" }
        "3" { $smsGateway = "@tmomail.net" }
        "4" { $smsGateway = "@messaging.sprintpcs.com" }
        "5" {
            Write-Host ""
            $smsGateway = Read-Host "Email-to-SMS gateway (e.g., @carrier.com)"
            if (-not $smsGateway.StartsWith("@")) {
                $smsGateway = "@" + $smsGateway
            }
        }
        default {
            Write-Host "Invalid choice, skipping SMS setup" -ForegroundColor Yellow
            $smsChoice = "2"
        }
    }

    if ($smsChoice -eq "1") {
        Write-Host ""
        $phoneNumber = Read-Host "Your 10-digit phone number (digits only)"

        # Clean phone number (remove any non-digits)
        $phoneNumber = $phoneNumber -replace '\D', ''

        if ($phoneNumber.Length -ne 10) {
            Write-Host "Invalid phone number, skipping SMS setup" -ForegroundColor Yellow
            $smsChoice = "2"
        } else {
            $smsAddress = $phoneNumber + $smsGateway

            # Optional: selective notifications (same as email)
            Write-Host ""
            Write-Host "SMS notification preferences:" -ForegroundColor Cyan
            Write-Host "  1. All tiers (always notify)" -ForegroundColor White
            Write-Host "  2. Only Bronze + Gold (20% and 40% discount tiers)" -ForegroundColor White
            Write-Host "  3. Only Gold (40% discount tier only)" -ForegroundColor White
            Write-Host "  4. Only when no discount" -ForegroundColor White
            Write-Host ""

            $smsTierChoice = Read-Host "Enter choice (1-4, default: 1)"

            $smsOnlyAlertOnTiers = switch ($smsTierChoice) {
                "2" { "Bronze,Gold" }
                "3" { "Gold" }
                "4" { "None" }
                default { "" }
            }

            # Save SMS configuration
            $config.SMS = @{
                To = $smsAddress
                OnlyAlertOnTiers = $smsOnlyAlertOnTiers
                Carrier = if ($carrier -eq "5") { "Custom" } else { @("Verizon", "AT&T", "T-Mobile", "Sprint")[[int]$carrier - 1] }
            }

            Write-Host ""
            Write-Host "[OK] SMS configuration saved" -ForegroundColor Green
            Write-Host "SMS will be sent to: $smsAddress" -ForegroundColor Cyan
        }
    }
} else {
    if ($smsChoice -ne "1") {
        Write-Host ""
        Write-Host "SMS setup skipped" -ForegroundColor Gray
    }
}

# ============================================================
# Save Configuration
# ============================================================
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Saving configuration..." -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan

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
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Testing EZPass connection..." -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

try {
    & ".\check-tolls.ps1" -Estimate

    if ($LASTEXITCODE -eq 1 -or $LASTEXITCODE -eq 2 -or $LASTEXITCODE -eq 3) {
        Write-Host ""
        Write-Host ("=" * 70) -ForegroundColor Green
        Write-Host "[OK] EZPass connection successful!" -ForegroundColor Green
        Write-Host ("=" * 70) -ForegroundColor Green

        # Test email if configured and updated
        if ($emailChoice -eq "1" -and $updateEmail -ne "skip") {
            Write-Host ""
            $testEmail = Read-Host "Would you like to send a test email? (yes/no)"

            if ($testEmail -eq "yes") {
                Write-Host ""
                Write-Host "Sending test email..." -ForegroundColor Cyan

                try {
                    & ".\notify-email.ps1"

                    Write-Host ""
                    Write-Host "[OK] Test email sent!" -ForegroundColor Green
                    Write-Host "Check your inbox at: $($config.Email.To)" -ForegroundColor Cyan
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

        # Test SMS if configured and updated
        if ($smsChoice -eq "1" -and $updateSms -ne "skip") {
            Write-Host ""
            $testSms = Read-Host "Would you like to send a test SMS? (yes/no)"

            if ($testSms -eq "yes") {
                Write-Host ""
                Write-Host "Sending test SMS..." -ForegroundColor Cyan

                try {
                    & ".\notify-sms.ps1"

                    Write-Host ""
                    Write-Host "[OK] Test SMS sent!" -ForegroundColor Green
                    Write-Host "Check your phone at: $($config.SMS.To)" -ForegroundColor Cyan
                } catch {
                    Write-Host ""
                    Write-Host "WARNING: Test SMS failed" -ForegroundColor Yellow
                    Write-Host "Error: $_" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Common issues:" -ForegroundColor Yellow
                    Write-Host "  - Verify your carrier's email-to-SMS gateway is correct" -ForegroundColor Gray
                    Write-Host "  - Some carriers may have delays (wait 1-2 minutes)" -ForegroundColor Gray
                    Write-Host "  - Try running: .\notify-sms.ps1 to test again" -ForegroundColor Gray
                }
            }
        }

        Write-Host ""
        Write-Host ("=" * 70) -ForegroundColor Green
        Write-Host "Setup Complete!" -ForegroundColor Green
        Write-Host ("=" * 70) -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now run:" -ForegroundColor Cyan
        Write-Host "  .\check-tolls.ps1 -Estimate       # Check your tolls" -ForegroundColor White
        Write-Host "  .\check-tolls.ps1 -Estimate -SmsFormat  # Check in SMS format" -ForegroundColor White

        if ($config.Email.SmtpServer) {
            Write-Host "  .\notify-email.ps1                # Send email notification" -ForegroundColor White
        }

        if ($config.SMS.To) {
            Write-Host "  .\notify-sms.ps1                  # Send SMS notification" -ForegroundColor White
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
