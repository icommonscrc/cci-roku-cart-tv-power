<#
One-time setup for the Roku cart TV schedule. Run in PowerShell as Administrator
from the folder that holds this file and CartTvPower.ps1:

    powershell -ExecutionPolicy Bypass -File .\Install-CartTvPower.ps1
#>
$ErrorActionPreference = 'Stop'
$dir = 'C:\ProgramData\CartTvPower'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'CartTvPower.ps1') -Destination $dir -Force

# Windows can turn Internet Connection Sharing off after a restart; this keeps it on.
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedAccess' `
    -Name 'EnableRebootPersistConnection' -PropertyType DWord -Value 1 -Force | Out-Null
Set-Service -Name SharedAccess -StartupType Automatic

# The PC has to stay awake to send the morning command.
powercfg /change standby-timeout-ac 0

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$dir\CartTvPower.ps1`""

# Every 10 minutes on the clock (:00, :10, ...), so 6:00 and 21:30 fall exactly on a run.
$every10 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 10)
# Also shortly after the PC starts, once the network is up.
$startup = New-ScheduledTaskTrigger -AtStartup
$startup.Delay = 'PT2M'

$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'Cart TV Power' -Action $action -Trigger $every10, $startup `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Installed. Script and log are in $dir"
