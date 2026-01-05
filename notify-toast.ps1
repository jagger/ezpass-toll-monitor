<#
.SYNOPSIS
Windows Toast notification for Maine EZPass Toll Monitor

.DESCRIPTION
Runs the toll check and displays a Windows 10/11 toast notification with the results.

.PARAMETER OnlyAlertOnTiers
Only show notification for specific tiers (comma-separated: None,Bronze,Gold)

.EXAMPLE
.\notify-toast.ps1

.EXAMPLE
.\notify-toast.ps1 -OnlyAlertOnTiers "Bronze,Gold"
#>

param(
    [string]$OnlyAlertOnTiers
)

# Check Windows version
if ([Environment]::OSVersion.Version.Major -lt 10) {
    Write-Host "Error: Toast notifications require Windows 10 or later" -ForegroundColor Red
    exit 1
}

# Run the toll check and capture output
Write-Host "Running toll check..." -ForegroundColor Cyan
$output = & ".\check-tolls.ps1" -Estimate 2>&1
$exitCode = $LASTEXITCODE

# Display the output
$output | ForEach-Object { Write-Host $_ }

# Convert output to string for error detection
$outputText = $output | Out-String

# Check for specific errors
$serviceUnavailable = $false
$tollCheckFailed = $false

if ($outputText -match "currently unavailable|service is currently unavailable") {
    $serviceUnavailable = $true
    $tollCheckFailed = $true
} elseif ($outputText -match "No toll data retrieved|Error:|Login failed|Login still failed") {
    $tollCheckFailed = $true
}

# Determine discount tier from exit code
$tierInfo = if ($tollCheckFailed) {
    if ($serviceUnavailable) {
        @{
            Name = "Service Unavailable"
            Title = "EZPass Service Unavailable"
            Message = "The Maine EZPass service is temporarily down. Try again later."
            Icon = "Warning"
        }
    } else {
        @{
            Name = "Error"
            Title = "EZPass Monitor Error"
            Message = "Failed to retrieve toll data. Check your connection or credentials."
            Icon = "Error"
        }
    }
} else {
    switch ($exitCode) {
        3 { @{
            Name = "None"
            Title = "No Discount Tier"
            Message = "On track for 0-29 tolls - no discount"
            Icon = "Warning"
        }}
        2 { @{
            Name = "Bronze"
            Title = "Bronze Tier - 20% Discount"
            Message = "On track for 30-39 tolls - 20% discount!"
            Icon = "Info"
        }}
        1 { @{
            Name = "Gold"
            Title = "Gold Tier - 40% Discount"
            Message = "On track for 40+ tolls - maximum 40% discount!"
            Icon = "Info"
        }}
        default { @{
            Name = "Unknown"
            Title = "EZPass Monitor Error"
            Message = "Error checking toll count"
            Icon = "Error"
        }}
    }
}

# Check if we should show notification for this tier
$shouldNotify = $true
if ($OnlyAlertOnTiers) {
    $alertTiers = $OnlyAlertOnTiers -split ','
    $shouldNotify = $alertTiers -contains $tierInfo.Name
}

if (-not $shouldNotify) {
    Write-Host ""
    Write-Host "INFO: No notification shown (tier '$($tierInfo.Name)' not in alert list)" -ForegroundColor Gray
    exit 0
}

# Extract toll count from output
$tollCount = "Unknown"
if ($output -match "Estimated month-end discount-eligible tolls: ([\d.]+)") {
    $tollCount = [math]::Round([decimal]$Matches[1], 0)
} elseif ($output -match "Discount-eligible tolls: (\d+)") {
    $tollCount = $Matches[1]
}

$detailedMessage = "$($tierInfo.Message)`n`nProjected tolls: $tollCount"

# Create toast notification using Windows.UI.Notifications
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    # Create toast XML
    $toastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Maine EZPass Monitor</text>
            <text>$($tierInfo.Title)</text>
            <text>Projected tolls: $tollCount</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default" />
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)

    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Maine EZPass Monitor").Show($toast)

    Write-Host ""
    Write-Host "[OK] Toast notification displayed!" -ForegroundColor Green

} catch {
    # Fallback to simple Windows notification
    Write-Host ""
    Write-Host "Toast notification not available, using balloon tip..." -ForegroundColor Yellow

    Add-Type -AssemblyName System.Windows.Forms

    $notification = New-Object System.Windows.Forms.NotifyIcon
    $notification.Icon = [System.Drawing.SystemIcons]::Information
    $notification.BalloonTipIcon = $tierInfo.Icon
    $notification.BalloonTipTitle = "Maine EZPass Monitor"
    $notification.BalloonTipText = $detailedMessage
    $notification.Visible = $true

    $notification.ShowBalloonTip(10000)

    # Keep the script running long enough to show the notification
    Start-Sleep -Seconds 2

    $notification.Dispose()

    Write-Host "[OK] Balloon notification displayed!" -ForegroundColor Green
}

exit 0
