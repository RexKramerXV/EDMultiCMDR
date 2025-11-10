# EDMultiCMDR

Status: November 10, 2025

Script to launch multiple CMDRs under one single login on a Windows computer. Uses [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher), specifically the [multi-account part](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#multi-account).

Describes a method to run concurrently multiple instances of [EDMarketConnector](https://github.com/EDCD/EDMarketConnector) (EDMC) tool specific to the CMDRs chosen.

## Prerequisites

- You have a standard Steam installation of E:D *and/or*
- You have a standard Frontier launcher installation.
- Optional: you have a standard installation of [EDMarketConnector](https://github.com/EDCD/EDMarketConnector).
- On your local Windows machine, user accounts exist for every CMDR you'd like to launch.
- You have installed [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher), and set it up in a way that it runs properly on every account intended to use concurrently, e.g.,
  - For Steam, the E:D launch command has to be adjusted to use the [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#steam).
  - For Frontier launcher, you have followed the [instructions here](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#frontier) and created a `/frontier` profile.
- You have run E:D, using Steam or Frontier launcher, at least once successfully in each account (when logged in directly into the account!).

## STEAM: Adapt the Steam launch command

- Follow [these instructions](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#steam) to adapt the Steam launcher command. For the launcher command, use `cmd /c "MinEdLauncher.exe %command% /autorun /autoquit"`

## FRONTIER: create the launch shortcut

- Place MinEdLauncher.exe in your Elite Dangerous install location so that it's in the same folder as EDLaunch.exe.
- Create a shortcut to MinEdLauncher.exe by right-clicking it and selecting create shortcut
- Right-click the newly made shortcut and select properties
- Add the `/frontier profile-name` argument (and your other desired arguments) to the end of the Target textbox (e.g. `C:\path\to\MinEdLauncher.exe /frontier profile-name /autorun /autoquit`)
- Click `Ok`

## What the script does

1. It reads credentials and metadata (Windows logon "username", an encrypted "password" blob, and "client" type ["steam","frontier","epic"]) from a local JSON file stored under %LOCALAPPDATA%\EDMultiCMDR\credentials.json.
    1. A UI is presented to select for which users to start E:D via MinEDLauncher, with default to all
    1. If there are no stored credentials, it will ask the user to create them.
1. It keeps track of already running Elite : Dangerous instances (process names `EliteDangerous64','EliteDangerous`)
1. it will check for "client" type - currently only Steam and Frontier launcher are supported
1. For each selected user from the UI, it will
    1. launch the game with the correct credentials via MinEDLauncher,
    1. wait (timeout of 30 seconds) until the NEW E:D process is started for the user,
    1. terminate the Steam process PID ~~or the Frontier launcher PID (this must be tested!)~~ it started for the user (as you cannot have run several instances of Steam in parallel for different users)

## Installation

1. Download the latest release archive from the project's GitHub releases page and extract it to a folder on your machine, e.g. C:\Program Files\EDMultiCMDR or C:\Users\<you>\Apps\EDMultiCMDR.
2. Create a Windows shortcut for easy access:
   - Right-click the Desktop (or Start menu folder) → New → Shortcut.
   - For the "Target" field use an invocation like:
     `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\EDMultiCMDR\EDMultiCMDR.ps1"`
   - Optionally set "Start in" to the install folder.

## Credentials storage & initialization

How credentials are handled - in the end, we're dealing with Windows credentials...

- The script stores account entries in a local JSON file under your user profile: %LOCALAPPDATA%\EDMultiCMDR\credentials.json.
- Passwords are not stored in plaintext. When you enter a password the script converts the SecureString to an encrypted string using PowerShell's ConvertFrom-SecureString (DPAPI). The JSON therefore contains encrypted password blobs.
- On use, the script converts the encrypted blob back to a SecureString (ConvertTo-SecureString) and builds a PSCredential to pass to Start-Process -Credential. At no point does the script write raw plaintext passwords to disk.
- The DPAPI encryption ties the stored password string to your Windows user account and machine. That means the encrypted strings can only be decrypted by the same Windows user on the same machine.

First-run initialization (what you must do)

1. Run the script (EDMultiCMDR.ps1). If no credentials file is present the script will prompt you to create accounts.
1. For each account:
   - Enter the Username (email or local Windows username). Leave blank to finish adding accounts.
   - Enter the Password when prompted. The input is read as a SecureString (hidden) and stored encrypted in the JSON.
   - Enter the Client type (press Enter for default "steam").
1. When finished the script writes %LOCALAPPDATA%\EDMultiCMDR\credentials.json containing the account entries with encrypted password strings.
1. Re-run the script anytime to add/remove accounts. Prefer using the script UI to edit accounts — manual edits to the JSON require you to provide ConvertFrom-SecureString output for passwords.

Notes and security considerations

- No external PowerShell modules are required; the implementation uses built-in ConvertFrom-SecureString/ConvertTo-SecureString (DPAPI).
- Because passwords are DPAPI-encrypted, the file is effectively private to your Windows user account on that machine. If you need to move credentials between machines or users you must re-enter them on the target account.
- If you want to reset or reinitialize storage, delete %LOCALAPPDATA%\EDMultiCMDR\credentials.json and re-run the script to create a new credentials file.
- Keep your Windows account secure (strong password, OS updates, disk encryption) because the stored credentials are only protected by the DPAPI tied to that account.


## Editing stored credentials interactively

The script provides a built-in interactive editor you can invoke with the -EditCredentials switch. This opens a menu where you can add, edit or remove entries and persist them to the credentials file.

Usage:
powershell -NoProfile -ExecutionPolicy Bypass -File .\EDMultiCMDR.ps1 -EditCredentials

Interactive commands:

- a  : add a new account (prompts for username, password, client; prompts for a Frontier profile when client=frontier). Changes are saved immediately.
- e N: edit account number N (1-based). You can change username, password, client and frontier profile. Changes are saved immediately.
- r N: remove account number N. Deletion is saved immediately after confirmation.
- s  : save current changes and exit (also auto-saved after add/edit/remove).
- q  : quit the editor (prompts before quitting without saving).

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

## Debug output

Note: the script emits diagnostic output via PowerShell's Write-Verbose. To see debugging details when running the script, invoke it with -Verbose e.g.:

```powershell
powershell -File .\EDMultiCMDR.ps1 -Verbose
```

## Outlook

What *may* be coming in future releases is

- robust support for Frontier launcher
- support for Epic Launcher
- support for non-standard Steam installations
- support for Linux

### Local JSON credential file (current)

```json
{
  "EDMultiCMDR": [
    {
      "username": "main@example.com",
      "password": "Encrypted_DPAPI_blob_here",
      "client": "steam"
    },
    {
      "username": "frontier.user",
      "password": "Encrypted_DPAPI_blob_here",
      "client": "frontier",
      "profile": "profile-name"
    }
  ]
}
```
