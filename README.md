# EDMultiCMDR

Scripts to launch multiple CMDRs on a single Windows machine, plus the [EDMarketConnector](https://github.com/EDCD/EDMarketConnector) tool specific to the CMDR chosen.

Uses [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher), specifically the [multi-account part](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#multi-account).

## How?

### Put the settings in place

`settings[-steam|-frontier].json` must be copied to `%LOCALAPPDATA%\min-ed-launcher\settings.json`. It ensures log files of the correct CMDR are parsed.

The `%LOCALAPPDATA%`refers to a directory *specific* to the CMDR - which enables us to launch programs (EDMC, VoiceAttack, EDDI, ED Discovery, ...) specific to that CMDR.

So, using the Windows usernames of the example scripts, the (maybe same) `settings.json`file would end up in three directories.

- `C:\Users\maincmdr\AppData\Local\min-ed-launcher\settings.json`for the Main CMDR,
- `C:\Users\alt1\AppData\Local\min-ed-launcher\settings.json`for the first alt CMDR,
- `C:\Users\alt2\AppData\Local\min-ed-launcher\settings.json`for the second alt CMDR.

Use the proper template depending on the type of account the CMDR uses: the only difference is that Steam installations require the `"gamelocation"`key in the JSON.

### Adapt your various Commanders

Adjust the PowerShell scripts for each of your commanders. Launch it once manually, do the authentication via Frontier website. The credentials will be stored for later use.

To be verified: the PowerShell must be run as Administrator?

### Creating proper shortcuts

Will be handled as soon as the concept works.

We must include the intended profiles when starting the launcher(s) by using the `/frontier ...` directive.

**Shortcut for Windows**
Create a shortcut with "Target": `cmd /c "MinEdLauncher.exe %command% /frontier <put your profile-name here> /autorun /autoquit"`

**Shortcut for Steam**
Follow [these instructions](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#steam) to adapt the Steam launcher command. For the launcher command, use `cmd /c "MinEdLauncher.exe %command% /frontier <put your profile-name here> /autorun /autoquit"`

Create a shortcut with "Target": `"C:\Program Files (x86)\Steam\Steam.exe" -gameidlaunch 359320 /edo`

## Default E:D installation directories

- **Frontier launcher, global installation**: `C:\Program Files (x86)\Frontier\Products\elite-dangerous-64\`
- **Frontier, user-specific installation**: `C:\Program Files (x86)\Steam\steamapps\common\Elite Dangerous\Products\elite-dangerous-64\`
- **Steam**: `C:\Program Files (x86)\Steam\steamapps\common\Elite Dangerous\Products\elite-dangerous-64\`
