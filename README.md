# EDMultiCMDR

Scripts to launch multiple CMDRs on a single Windows machine, plus the [EDMarketConnector](https://github.com/EDCD/EDMarketConnector) tool specific to the CMDR chosen.

Uses [MinEDLauncher](https://github.com/rfvgyhn/min-ed-launcher), specifically the [multi-account part](https://github.com/rfvgyhn/min-ed-launcher?tab=readme-ov-file#multi-account).

## How?

### Put the settings in place

`settings.json` must be copied to `%LOCALAPPDATA%\min-ed-launcher\settings.json`. It ensures log files of the correct CMDR are parsed.

### Adapt your various Commanders

Create one PowerShell script for each of your commanders. Launch it once manually, do the authentication via Frontier website. The credentials will be stored for later use.

## Create a release zip

Use PowerShell (Windows PowerShell 5 or PowerShell 7+) from the repo root:

```powershell
pwsh ./create-release.ps1 -Version v1.0.0
```

The script zips the repository (skipping `.git` and previous archives) into `./dist/EDMultiCMDR-v1.0.0.zip`. Omit `-Version` to fall back to a timestamped filename.

### Automated GitHub release

Pushing a tag that starts with `v` (for example `v1.0.0`) triggers the `Publish Release Zip` GitHub Action. It runs `create-release.ps1 -Version <tag>` on `windows-latest` and attaches the generated `dist/EDMultiCMDR-<tag>.zip` to the GitHub release created from that tag.
