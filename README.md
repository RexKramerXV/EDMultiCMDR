# EDMultiCMDR

Status: November 10, 2025

Script to launch multiple CMDRs under one single login on a Windows computer. Uses [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher), specifically the [multi-account part](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#multi-account).

Describes a method to run concurrently multiple instances of [EDMarketConnector](https://github.com/EDCD/EDMarketConnector) (EDMC) tool specific to the CMDRs chosen.

## Prerequisites

- You have a standard Steam installation of E:D.
- Optional: you have a standard installation of [EDMarketConnector](https://github.com/EDCD/EDMarketConnector).
- You have installed [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher).
- On your local Windows machine, user accounts exist for every CMDR you'd like to launch.
- In each of theses accounts, the E:D launch command has to be adjusted in Steam to use the MinEDLauncher.
- You have adapted the launch command in Steam to use [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#steam).

## Adapt the Steam launch command

Follow [these instructions](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#steam) to adapt the Steam launcher command. For the launcher command, use `cmd /c "MinEdLauncher.exe %command% /autorun /autoquit"`

## What the script does

1. It reads [credentials and metadata](#windows-credential-manager-storage---json-blob-current) (Windows Logon ("username", "password" and "client" type ["Steam","Frontier","Epic"]) from Windows Credential Manager.
    1. A UI is presented to select for which users to start E:D via MinEDLauncher, with default to all
    1. If there are no stored Credentials, it will ask the user to create them.
1. It keeps track of already running Elite : Dangerous instances (process names `EliteDangerous64','EliteDangerous`)
1. it will check for "client" type - currently only Steam is supported
1. For each selected user from the UI, it will
    1. start Steam process,
    1. waits (timeout of 30 seconds) until the NEW E:D process is started for the user,
    1. terminates the Steam process PID it started for the user (as you cannot have run several instances of Steam in parallel for different users)

## How to launch additional processes

Trigger for this repo was the wish to run several CMDRs in parallel, while running multiple instances of EDMC for each of them.

This can be done via [MinEDLauncher's `settings.json`](https://github.com/rfvgyhn/min-ed-launcher#settings).

After first launch of MinEDLaucher, it will place a default `settings.json` file under `%LOCALAPPDATA%\min-ed-launcher\settings.json`.

```json
{
    "apiUri": "https://api.zaonce.net",
    "watchForCrashes": false,
    "language": null,
    "autoUpdate": true,
    "checkForLauncherUpdates": true,
    "maxConcurrentDownloads": 4,
    "forceUpdate": "",
    "processes": [],
    "shutdownProcesses": [],
    "filterOverrides": [
        { "sku": "FORC-FDEV-DO-1000", "filter": "edo" },
        { "sku": "FORC-FDEV-DO-38-IN-40", "filter": "edh4" }
    ],
    "additionalProducts": []
}
```

This can be modified to automagically launch EDMC under the ***user running E:D via MinEDLauncher***.

**Easiest way to access this file is to log in locally with each CMDR account and work directly under their user access rights - open Steam, modify the launcher command and start it once.** Then,

substitute `"processes": []," with

```json
   "processes": [
        {
            "fileName": "C:\\Program Files (x86)\\EDMarketConnector\\EDMarketConnector.exe",
            "arguments": "--force-localserver-for-auth"
        }
    ],
```

And your good to go. Feel free to add more programs. Another example for running EDMC and [VoiceAttack](https://voiceattack.com/) (e.g. for your main account only) would be

```json
   "processes": [
        {
            "fileName": "C:\\Program Files (x86)\\EDMarketConnector\\EDMarketConnector.exe",
            "arguments": "--force-localserver-for-auth"
        },
        {
            "fileName": "C:\\Program Files\\VoiceAttack\\VoiceAttack.exe"
        }
    ],
```

or [EDDiscovery](https://github.com/EDDiscovery/EDDiscovery/wiki)

```json
   "processes": [
        {
            "fileName": "C:\\Program Files\\EDDiscovery\\EDDiscovery.exe"
        }
    ],
```

or [EDDI](https://github.com/EDCD/EDDI), or whatever floats your boat.

## Key functionality and formats

### Steam process launch

```powershell
Write-Host "Starting Steam (steam.exe) as $username..."
$steamProc = Start-Process -FilePath "C:\Program Files (x86)\Steam\steam.exe" `
    -ArgumentList '-silent','-gameidlaunch','359320' `
    -Credential $cred `
    -WorkingDirectory "C:\Program Files (x86)\Steam" `
    -PassThru
```

### Windows Credential Manager Storage - JSON blob (current)

```json
{
  "EDMultiCMDR": [
    {
      "username": "main@example.com",
      "password": "main_password",
      "client": "steam"
    },
    {
      "username": "alt1@example.com",
      "password": "alt1_password",
      "client": "steam"
    },
    {
      "username": "alt2@example.com",
      "password": "alt2_password",
      "client": "steam"
    }
  ]
}
```

## Outlook

What *may* be coming in future releases is

- support for Linux
- support for Frontier launcher
- support for Epic Launcher
- support for non-standard Steam installations
