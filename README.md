# Roku Cart TV Power Schedule

PowerShell scripts that turn a Roku TV on at 6:00 AM and off at 9:30 PM for **Drexel SCIS Commons** rolling cart displays, driven from the Windows Tiny PC on the cart.

## What It Does

- Sends Roku's local control commands (ECP, port 8060) over an Ethernet cable that runs straight from the Tiny PC to the TV
- Checks the TV every 10 minutes: turns it on (and switches to HDMI 1) during the day, off overnight
- Recovers on its own after power cuts, PC restarts and missed commands
- Finds the TV again if its address changes
- Logs every change to `C:\ProgramData\CartTvPower\cart-tv-power.log`

Consumer smart TVs ignore a returning HDMI signal once they drop into standby, and they always come back from a power cut in standby. Network commands still reach them in standby, which is why this works where screen-off scripts and outlet timers don't.

## Prerequisites

- PowerShell 5.1+ (Windows 10/11), run as Administrator for the install
- Roku TV with an Ethernet port, activated on a Roku account
- Tiny PC on the TV's HDMI 1, connected to the network over Wi-Fi (its Ethernet port goes to the TV)
- An Ethernet cable

## Setup

### 1. Connect the TV to the Tiny PC

1. Plug the Ethernet cable into the TV and the Tiny PC.
2. Press **Win+R**, run `ncpa.cpl`, right-click **Wi-Fi** → **Properties** → **Sharing**.
3. Tick **Allow other network users to connect through this computer's Internet connection**, untick the second box, click **OK**.
4. In Windows settings, set **Turn off screen** and **Put device to sleep** to **Never**, and **Require sign-in when away** to **Never**.

### 2. Roku TV settings

| Where | Set to |
|---|---|
| Settings → Network → Connect and activate now | **Wired** |
| Settings → System → Power → **Power On** | **Last input** |
| Settings → System → Power → **Auto power savings** | Keep "Reduce power after 15 minutes", untick any "Turn off after 4 hours" |
| Settings → System → Time → **Sleep timer** | **Off** |
| Settings → System → Advanced system settings → Control by mobile apps → **Network access** | **Enabled** ("Limited" returns 403 Forbidden) |
| Settings → Privacy → **Smart TV experience** | Untick all three boxes |

## Usage

Install once, in **Terminal (Admin)** from the folder holding both scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-CartTvPower.ps1
```

The installer copies the script to `C:\ProgramData\CartTvPower`, keeps Internet Connection Sharing on after restarts, stops the PC from sleeping, and creates the **Cart TV Power** scheduled task (every 10 minutes and 2 minutes after startup, as SYSTEM).

Test it:

```powershell
# TV should turn off
powershell -ExecutionPolicy Bypass -File C:\ProgramData\CartTvPower\CartTvPower.ps1 -OffTime 00:00

# TV should turn back on to HDMI 1 (during the day)
Start-ScheduledTask -TaskName 'Cart TV Power'

# Log should show "Turned TV off." and "Turned TV on"
Get-Content C:\ProgramData\CartTvPower\cart-tv-power.log -Tail 5
```

## Notes

- **Change the hours:** edit `$OnTime` and `$OffTime` at the top of `C:\ProgramData\CartTvPower\CartTvPower.ps1`.
- **TV address:** the current one is in `C:\ProgramData\CartTvPower\tv-ip.txt`. Manual commands (use `curl.exe`, not `curl`):
  ```powershell
  curl.exe -i -X POST http://192.168.137.X:8060/keypress/PowerOff
  curl.exe -i -X POST http://192.168.137.X:8060/keypress/PowerOn
  ```
- **Troubleshooting:**
  - "Requested registry access is not allowed" during install → run the terminal as Administrator
  - Log says "TV not found on the shared link" → check the cable; `ipconfig` must show 192.168.137.1 on Ethernet
  - `403 Forbidden` → set Network access to **Enabled**
  - TV turns on to the Roku home screen → set Power On to **Last input**
- **Remove:**
  ```powershell
  Unregister-ScheduledTask -TaskName 'Cart TV Power' -Confirm:$false
  Remove-Item C:\ProgramData\CartTvPower -Recurse
  ```
