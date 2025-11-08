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
