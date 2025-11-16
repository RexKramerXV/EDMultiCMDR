<#
Creates a zip of the repository contents for distribution.

Usage:
  pwsh ./create-release.ps1 [-Version v1.2.3]

The script drops release archives under ./dist.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [ValidatePattern('^v?\d+\.\d+\.\d+$')]
    [string]$Version
)

$repoRoot = $PSScriptRoot
$distDir = Join-Path $repoRoot 'dist'
New-Item -Path $distDir -ItemType Directory -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archiveName = if ([string]::IsNullOrWhiteSpace($Version)) {
    "EDMultiCMDR-$timestamp.zip"
}
else {
    "EDMultiCMDR-$Version.zip"
}
$archivePath = Join-Path $distDir $archiveName

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

$releaseListPath = Join-Path $repoRoot 'release-files.txt'
if (-not (Test-Path $releaseListPath)) {
    throw "release-files.txt not found at $releaseListPath"
}

$entries = Get-Content $releaseListPath |
ForEach-Object { $_.Trim() } |
Where-Object { $_ -and -not $_.StartsWith('#') }

if (-not $entries -or $entries.Count -eq 0) {
    throw "release-files.txt contains no usable entries."
}

$pathsToPackage = @()

foreach ($entry in $entries) {
    # relative Pfade auf Repo-Root beziehen
    $isRooted = [System.IO.Path]::IsPathRooted($entry)
    $searchPath = if ($isRooted) { $entry } else { Join-Path $repoRoot $entry }

    $hasWildcard = [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($searchPath)

    if ($hasWildcard) {
        $matches = Get-ChildItem -Path $searchPath -File -Recurse -ErrorAction SilentlyContinue
        if ($matches) {
            $pathsToPackage += $matches.FullName
        }
        else {
            Write-Warning "Pattern '$entry' did not match any files."
        }
        continue
    }

    if (-not (Test-Path $searchPath)) {
        Write-Warning "Requested release path not found and will be skipped: $entry"
        continue
    }

    $item = Get-Item $searchPath

    if ($item.PSIsContainer) {
        $files = Get-ChildItem -Path $item.FullName -File -Recurse
        if ($files) {
            $pathsToPackage += $files.FullName
        }
        else {
            Write-Warning "Directory '$entry' contains no files and will be skipped."
        }
    }
    else {
        $pathsToPackage += $item.FullName
    }
}

$pathsToPackage = $pathsToPackage | Sort-Object -Unique

if (-not $pathsToPackage -or $pathsToPackage.Count -eq 0) {
    throw "Nothing to package — no files resolved from release-files.txt."
}

Write-Host "Creating release archive at $archivePath"
Write-Host "Including files:"
$pathsToPackage | ForEach-Object { Write-Host " - $_" }

Compress-Archive -Path $pathsToPackage -DestinationPath $archivePath -Force

Write-Host "Created release archive at $archivePath"
