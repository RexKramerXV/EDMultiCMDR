# EDMultiCMDR

Launch multiple Elite Dangerous commanders concurrently from one Windows login using [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher) (Steam or Frontier). Scripted in PowerShell for a fast, repeatable startup flow.

![EDMultiCMDR overview](3CMDRs+YT.png)

## What it does

- Start selected accounts with [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher) multi-account support and auto-login.
- Store account metadata in `%LOCALAPPDATA%\EDMultiCMDR\credentials.json` with DPAPI-encrypted passwords.
- Support Steam and Frontier clients, including optional Frontier profiles and per-account `launcherPath` overrides.
- Optionally trigger EDMarketConnector or other tools via MinEDLauncher `processes` hooks.

## Requirements

- Elite Dangerous installed via Steam and/or Frontier launcher (Epic is not supported).
- [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher) installed and working for each account (***run it once per account manually to verify***).
- Optional: companion apps such as EDMarketConnector, VoiceAttack, EDDiscovery, or EDDI.
- Windows with PowerShell 5.1 or later (comes pre-installed with Windows 10 and 11)

## Set up MinEDLauncher

- **Steam**: set Steam launch options to `cmd /c "MinEdLauncher.exe %command% /autorun /autoquit"` per the MinEDLauncher Steam instructions.
- **Frontier**: place `MinEdLauncher.exe` next to `EDLaunch.exe`, create a shortcut, and add `/frontier <profile> /autorun /autoquit` to the Target. If MinEDLauncher lives in a non-standard path, record it per account via `launcherPath`.

## Install EDMultiCMDR

1. Download the latest release ZIP from the GitHub releases page.
2. Extract to a folder, e.g. `C:\Program Files\EDMultiCMDR` or `C:\Users\<you>\Apps\EDMultiCMDR`.
3. Create a shortcut that runs `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\EDMultiCMDR\EDMultiCMDR.ps1"` (optional: set "Start in" to the install folder).

## Configure accounts (first run)

- Run the script; if no credentials exist you will be prompted to add accounts.
- Captured fields: `username`, `password` (encrypted), `client` (`steam` or `frontier`), optional Frontier `profile`, and optional `launcherPath` when the launcher is not in its default location.
- Credentials are stored at `%LOCALAPPDATA%\EDMultiCMDR\credentials.json` using DPAPI, so they can only be decrypted by the same Windows user on the same machine.
- Use `-EditCredentials` to add or update entries later. Delete the credentials file to start fresh if needed.

## Run the launcher

- Start the script normally or via your shortcut.
- Select which accounts to start (supports comma/range selection or `all`). The script:
  - Detects already-running Elite Dangerous processes.
  - Starts MinEDLauncher for each selected account and waits for the new game process.
  - Closes the launcher process it started (Steam/Frontier) to allow multiple concurrent sessions.
- Useful options: `-Help` (usage), `-Verbose` (diagnostics), `-EditCredentials` (manage accounts only).

## Auto-launch companion apps (optional)

- Edit `%LOCALAPPDATA%\min-ed-launcher\settings.json` and populate `"processes"` per the MinEDLauncher docs. Example for EDMarketConnector:

```json
"processes": [
  {
    "fileName": "C:\\Program Files (x86)\\EDMarketConnector\\EDMarketConnector.exe",
    "arguments": "--force-localserver-for-auth"
  }
]
```

- Add further entries for tools like [VoiceAttack](https://voiceattack.com/), [EDDiscovery](https://github.com/EDDiscovery/EDDiscovery/wiki), or [EDDI](https://github.com/EDCD/EDDI) as desired.

## Troubleshooting

- Ensure each Windows account has launched Elite Dangerous at least once directly through its launcher.
- Follow the [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher) installation instructions, specifically the [multi-account part](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#multi-account).
- Use `-Verbose` to see credential loading, account selection, and process wait details.
- Verify `launcherPath` for Frontier accounts if the script cannot find MinEDLauncher.
- Delete `%LOCALAPPDATA%\EDMultiCMDR\credentials.json` and re-run the script if the credential file becomes corrupted.

## License

MIT License (see `LICENSE`).
