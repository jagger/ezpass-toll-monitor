# Configuration Guide

The Maine EZPass Toll Monitor uses secure, encrypted configuration stored in your Windows user profile.

## Quick Setup

Simply run the interactive setup script:

```powershell
.\setup.ps1
```

This will guide you through:
1. EZPass credentials (required)
2. Email notifications (optional)

## Configuration Location

All configuration is stored in: `C:\Users\[YourUsername]\.ezpass\`

### Files Created

- `config.xml` - Encrypted credentials and settings (created by setup)
- `cookies.xml` - Session cache, auto-generated (10-minute TTL)

## Security

**Encryption Method:** Windows Data Protection API (DPAPI)
- Passwords are stored as SecureString objects
- Can only be decrypted by your Windows user account
- Safe from plaintext credential exposure

## Configuration Structure

The `config.xml` file contains the following structure:

```powershell
@{
    EZPass = @{
        Username = "your_ezpass_username"
        Password = <SecureString encrypted by DPAPI>
    }
    Email = @{
        SmtpServer = "smtp.gmail.com"           # SMTP server address
        Port = 587                                # SMTP port (usually 587)
        From = "your-email@gmail.com"            # Sender email
        To = "your-email@gmail.com"              # Recipient email
        Username = "your-email@gmail.com"        # SMTP username
        Password = <SecureString encrypted by DPAPI>
        UseSsl = $true                           # Use SSL/TLS
        OnlyAlertOnTiers = ""                    # Filter notifications
    }
}
```

## Email Provider Settings

### Gmail (Recommended)

**SMTP Server:** `smtp.gmail.com`
**Port:** `587`
**SSL:** Required

**Setup Steps:**
1. Enable 2-Factor Authentication on your Google account
2. Go to: https://myaccount.google.com/apppasswords
3. Create an App Password for "Mail" on "Windows Computer"
4. Use the 16-character app password (NOT your Gmail password)

### Outlook/Hotmail

**SMTP Server:** `smtp.office365.com`
**Port:** `587`
**SSL:** Required

Use your regular Outlook/Hotmail password.

### Yahoo

**SMTP Server:** `smtp.mail.yahoo.com`
**Port:** `587`
**SSL:** Required

**Setup Steps:**
1. Go to Yahoo Account Security settings
2. Generate an App Password
3. Use the app password (NOT your Yahoo password)

### Custom SMTP

You can use any SMTP server by providing:
- SMTP server address
- Port number (default: 587)
- Your email credentials

## Notification Preferences

The `OnlyAlertOnTiers` setting filters which discount tiers trigger email notifications:

| Setting | Behavior |
|---------|----------|
| `""` (empty) | Notify for all tiers |
| `"Bronze,Gold"` | Only notify for Bronze (20%) and Gold (40%) tiers |
| `"Gold"` | Only notify for Gold (40%) tier |
| `"None"` | Only notify when no discount tier |

**Note:** Error notifications (login failures, service unavailable) are always sent regardless of this setting.

## Manual Configuration

While the interactive setup is recommended, you can manually create the config using PowerShell:

```powershell
# Create config directory
$configDir = Join-Path $env:USERPROFILE ".ezpass"
New-Item -Path $configDir -ItemType Directory -Force

# Create config structure
$config = @{
    EZPass = @{
        Username = "your_username"
        Password = ConvertTo-SecureString "your_password" -AsPlainText -Force
    }
    Email = @{
        SmtpServer = "smtp.gmail.com"
        Port = 587
        From = "your-email@gmail.com"
        To = "your-email@gmail.com"
        Username = "your-email@gmail.com"
        Password = ConvertTo-SecureString "your_app_password" -AsPlainText -Force
        UseSsl = $true
        OnlyAlertOnTiers = ""
    }
}

# Save encrypted config
$configFile = Join-Path $configDir "config.xml"
$config | Export-Clixml -Path $configFile -Force
```

## Updating Configuration

To update your configuration, simply run setup again:

```powershell
.\setup.ps1
```

The setup script will:
- Detect existing configuration
- Ask if you want to update it
- Preserve settings you don't change

## Troubleshooting

### Config File Not Found

If scripts report "Configuration not found":
1. Run `.\setup.ps1` to create configuration
2. Ensure setup completed successfully

### Invalid Credentials

If scripts report login failures:
1. Verify credentials at https://ezpassmaineturnpike.com
2. Run `.\setup.ps1` to reconfigure
3. For Gmail: Ensure you're using an App Password, not your regular password

### Email Not Sending

Common issues:
- **Gmail:** Must use App Password with 2FA enabled
- **Yahoo:** Must use App Password
- **Outlook:** Regular password should work
- Check SMTP server and port are correct

### Corrupted Config

If config appears corrupted:
1. Delete `~\.ezpass\config.xml`
2. Run `.\setup.ps1` to recreate

### Session Cache Issues

If you get "account already logged in" errors:
1. Delete `~\.ezpass\cookies.xml`
2. Wait 5 minutes before trying again

## Security Best Practices

1. **Never commit config files to version control**
   - The repository `.gitignore` excludes these files
   - Config files contain encrypted but sensitive data

2. **Keep your Windows account secure**
   - Config encryption is tied to your Windows user account
   - Anyone with access to your Windows account can decrypt config

3. **Use App Passwords**
   - For Gmail and Yahoo, always use app-specific passwords
   - Never use your primary email password

4. **Regular updates**
   - If you change your EZPass or email password, run setup again
   - Old cached sessions will be invalidated automatically

## Advanced: Programmatic Access

To access config from your own scripts:

```powershell
# Load config
$configFile = Join-Path $env:USERPROFILE ".ezpass\config.xml"
$config = Import-Clixml -Path $configFile

# Get EZPass username
$username = $config.EZPass.Username

# Decrypt password
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($config.EZPass.Password)
)

# Get email settings
$smtpServer = $config.Email.SmtpServer
$port = $config.Email.Port

# Create email credential
$emailCredential = New-Object PSCredential(
    $config.Email.Username,
    $config.Email.Password
)
```
