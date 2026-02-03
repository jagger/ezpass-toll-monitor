# Configuration Guide

The Maine EZPass Toll Monitor stores configuration securely on each platform.

## Quick Setup

Run the interactive setup script for your platform:

**Windows:**
```powershell
windows\setup.ps1
```

**Linux/macOS:**
```bash
linux/setup.sh
```

This will guide you through:
1. EZPass credentials (required)
2. Email notifications (optional)
3. SMS notifications (optional)

---

## Windows Configuration

### Configuration Location

All configuration is stored in: `C:\Users\[YourUsername]\.ezpass\`

**Files Created:**
- `config.xml` - Encrypted credentials and settings (created by setup)
- `cookies.xml` - Session cache, auto-generated (10-minute TTL)

### Security

**Encryption Method:** Windows Data Protection API (DPAPI)
- Passwords are stored as SecureString objects
- Can only be decrypted by your Windows user account
- Safe from plaintext credential exposure

### Configuration Structure

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
    SMS = @{
        To = "5551234567@vtext.com"              # Carrier gateway address
        Carrier = "Verizon"                       # Carrier name
        OnlyAlertOnTiers = ""                    # Filter notifications
    }
}
```

### Manual Configuration (Windows)

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

---

## Linux/macOS Configuration

### Configuration Location

Non-sensitive settings: `~/.ezpass/config.json`
Credentials: Stored via the best available backend (see below)
Session cache: `~/.ezpass/cookies.txt` (auto-generated, 10-minute TTL)

### Credential Storage Backends

The credential helper (`linux/lib/credentials.sh`) automatically detects the best available backend:

| Priority | Backend | Platform | How It Works |
|----------|---------|----------|--------------|
| 1 | **macOS Keychain** | macOS | Uses `security add-generic-password` / `find-generic-password` |
| 2 | **pass** | Linux | Standard Unix password manager (GPG-based) |
| 3 | **OpenSSL** | Any | AES-256-CBC encrypted file at `~/.ezpass/config.enc` |

**Service names used:**
- `ezpass-monitor/username` - EZPass account username
- `ezpass-monitor/password` - EZPass account password
- `ezpass-monitor/email-password` - SMTP email password

### JSON Config Structure

The `~/.ezpass/config.json` file stores non-sensitive settings:

```json
{
  "email": {
    "smtp_server": "smtp.gmail.com",
    "port": 587,
    "from": "your-email@gmail.com",
    "to": "your-email@gmail.com",
    "username": "your-email@gmail.com",
    "use_ssl": true,
    "only_alert_on_tiers": ""
  },
  "sms": {
    "to": "5551234567@vtext.com",
    "carrier": "Verizon",
    "only_alert_on_tiers": ""
  },
  "version": 1
}
```

### Manual Configuration (Linux/macOS)

```bash
# Create config directory
mkdir -p ~/.ezpass
chmod 700 ~/.ezpass

# Store credentials (uses best available backend)
source /path/to/linux/lib/credentials.sh
store_password "ezpass-monitor/username" "your_username"
store_password "ezpass-monitor/password" "your_password"
store_password "ezpass-monitor/email-password" "your_app_password"

# Create config.json for non-sensitive settings
cat > ~/.ezpass/config.json << 'EOF'
{
  "email": {
    "smtp_server": "smtp.gmail.com",
    "port": 587,
    "from": "your-email@gmail.com",
    "to": "your-email@gmail.com",
    "username": "your-email@gmail.com",
    "use_ssl": true,
    "only_alert_on_tiers": ""
  },
  "version": 1
}
EOF
chmod 600 ~/.ezpass/config.json
```

---

## Email Provider Settings

### Gmail (Recommended)

**SMTP Server:** `smtp.gmail.com`
**Port:** `587`
**SSL:** Required

**Setup Steps:**
1. Enable 2-Factor Authentication on your Google account
2. Go to: https://myaccount.google.com/apppasswords
3. Create an App Password for "Mail"
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

The `OnlyAlertOnTiers` / `only_alert_on_tiers` setting filters which discount tiers trigger notifications:

| Setting | Behavior |
|---------|----------|
| `""` (empty) | Notify for all tiers |
| `"Bronze,Gold"` | Only notify for Bronze (20%) and Gold (40%) tiers |
| `"Gold"` | Only notify for Gold (40%) tier |
| `"None"` | Only notify when no discount tier |

**Note:** Error notifications (login failures, service unavailable) are always sent regardless of this setting.

## Updating Configuration

To update your configuration, run setup again:

**Windows:**
```powershell
windows\setup.ps1
```

**Linux/macOS:**
```bash
linux/setup.sh
```

The setup script will detect existing configuration and allow you to update specific settings.

## Troubleshooting

### Config File Not Found

If scripts report "Configuration not found":
1. Run setup to create configuration
2. Ensure setup completed successfully

### Invalid Credentials

If scripts report login failures:
1. Verify credentials at https://ezpassmaineturnpike.com
2. Run setup to reconfigure
3. For Gmail: Ensure you're using an App Password

### Email Not Sending

Common issues:
- **Gmail:** Must use App Password with 2FA enabled
- **Yahoo:** Must use App Password
- **Outlook:** Regular password should work
- Check SMTP server and port are correct

### Corrupted Config

**Windows:**
```powershell
Remove-Item ~\.ezpass\config.xml
windows\setup.ps1
```

**Linux/macOS:**
```bash
rm ~/.ezpass/config.json ~/.ezpass/config.enc
linux/setup.sh
```

### Session Cache Issues

If you get "account already logged in" errors:

**Windows:** Delete `~\.ezpass\cookies.xml`
**Linux/macOS:** Delete `~/.ezpass/cookies.txt`

Then wait 5 minutes before trying again.

## Security Best Practices

1. **Never commit config files to version control**
   - The repository `.gitignore` excludes these files
   - Config files contain encrypted but sensitive data

2. **Keep your account secure**
   - Windows: Config encryption is tied to your Windows user account
   - Linux/macOS: Use `pass` with a strong GPG key for best security

3. **Use App Passwords**
   - For Gmail and Yahoo, always use app-specific passwords
   - Never use your primary email password

4. **Regular updates**
   - If you change your EZPass or email password, run setup again
   - Old cached sessions will be invalidated automatically

## Advanced: Programmatic Access

### Windows

```powershell
$configFile = Join-Path $env:USERPROFILE ".ezpass\config.xml"
$config = Import-Clixml -Path $configFile
$username = $config.EZPass.Username
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($config.EZPass.Password)
)
```

### Linux/macOS

```bash
source /path/to/linux/lib/credentials.sh
username="$(get_password "ezpass-monitor/username")"
password="$(get_password "ezpass-monitor/password")"

# Read non-sensitive settings
smtp_server=$(python3 -c "import json; print(json.load(open('$HOME/.ezpass/config.json'))['email']['smtp_server'])")
```
