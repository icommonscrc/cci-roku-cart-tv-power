<#
Keeps a Roku TV on during the day and off overnight.

Task Scheduler runs this every 10 minutes. Each run reads the TV's power state
over Roku's local control API (port 8060) on the private Internet Connection
Sharing link (192.168.137.x) and corrects it:
  - between OnTime and OffTime: turn the TV on if it is off, then select the input
  - outside those hours: turn the TV off if it is on
Running every 10 minutes means a missed command, a power cut or a TV switched
off with the remote is fixed on the next run.
#>
param(
    [string]$OnTime  = '06:00',
    [string]$OffTime = '21:30',
    [string]$InputKey = 'InputHDMI1',
    [string]$Subnet  = '192.168.137',
    [string]$DataDir = 'C:\ProgramData\CartTvPower'
)

$ErrorActionPreference = 'Stop'
$LogFile = Join-Path $DataDir 'cart-tv-power.log'
$IpFile  = Join-Path $DataDir 'tv-ip.txt'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

function Write-Log([string]$Message) {
    # Keep the log small: start a new one past 1 MB, keeping the previous as .old.
    if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 1MB) {
        Move-Item $LogFile "$LogFile.old" -Force
    }
    '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message | Add-Content -Path $LogFile
}

function Get-PowerMode([string]$Ip) {
    $resp = Invoke-WebRequest -Uri "http://${Ip}:8060/query/device-info" -UseBasicParsing -TimeoutSec 5
    return ([xml]$resp.Content).'device-info'.'power-mode'
}

function Send-Key([string]$Ip, [string]$Key) {
    Invoke-WebRequest -Uri "http://${Ip}:8060/keypress/$Key" -Method Post -UseBasicParsing -TimeoutSec 5 | Out-Null
}

function Find-Tv {
    # The TV's address can change after a restart. Knock on port 8060 at every
    # address on the shared link at once; the TV is the only device that answers.
    $attempts = foreach ($n in 2..254) {
        $client = New-Object System.Net.Sockets.TcpClient
        [pscustomobject]@{ Ip = "$Subnet.$n"; Client = $client; Task = $client.ConnectAsync("$Subnet.$n", 8060) }
    }
    Start-Sleep -Milliseconds 1500
    $found = $null
    foreach ($a in $attempts) {
        if (-not $found -and $a.Task.Status -eq 'RanToCompletion') { $found = $a.Ip }
        $a.Client.Close()
    }
    return $found
}

function Get-TvIp {
    if (Test-Path $IpFile) {
        $ip = (Get-Content $IpFile -Raw).Trim()
        try { Get-PowerMode $ip | Out-Null; return $ip } catch { }
    }
    $ip = Find-Tv
    if ($ip) {
        Set-Content -Path $IpFile -Value $ip
        Write-Log "Found TV at $ip"
    }
    return $ip
}

$now = (Get-Date).TimeOfDay
$wantOn = ($now -ge [timespan]$OnTime) -and ($now -lt [timespan]$OffTime)

$ip = Get-TvIp
if (-not $ip) {
    Write-Log 'TV not found on the shared link (still starting up, unplugged, or sharing is off). Retrying next run.'
    exit 1
}

try {
    $mode = Get-PowerMode $ip
    $isOn = $mode -eq 'PowerOn'

    if ($wantOn -and -not $isOn) {
        Send-Key $ip 'PowerOn'
        # Give the TV time to wake before choosing the input.
        Start-Sleep -Seconds 15
        Send-Key $ip $InputKey
        Write-Log "Turned TV on (was $mode)."
    }
    elseif (-not $wantOn -and $isOn) {
        Send-Key $ip 'PowerOff'
        Write-Log 'Turned TV off.'
    }
}
catch {
    Write-Log "Error talking to TV at ${ip}: $($_.Exception.Message)"
    exit 1
}
