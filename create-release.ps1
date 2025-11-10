<#
Creates a zip of the repository contents for distribution.

Usage:
  pwsh ./create-release.ps1 [-Version v1.2.3]

The script drops release archives under ./dist.
#>

[CmdletBinding()]
param(
    [string]$Version
)

$repoRoot = $PSScriptRoot
$distDir = Join-Path $repoRoot 'dist'
New-Item -Path $distDir -ItemType Directory -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archiveName = if ([string]::IsNullOrWhiteSpace($Version)) {
    "EDMultiCMDR-$timestamp.zip"
} else {
    "EDMultiCMDR-$Version.zip"
}
$archivePath = Join-Path $distDir $archiveName

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

# Explicitly include only these files in the release bundle:
$includeNames = @(
    'EDMultiCMDR.ps1',
    'LICENSE',
    'README.md',
    'settings.examples.json'
)

$pathsToPackage = @()
foreach ($name in $includeNames) {
    $full = Join-Path $repoRoot $name
    if (Test-Path $full) {
        $pathsToPackage += $full
    } else {
        Write-Warning "Requested release file not found and will be skipped: $name"
    }
}

if (-not $pathsToPackage -or $pathsToPackage.Count -eq 0) {
    throw "Nothing to package — none of the requested files were found under $repoRoot"
}

Compress-Archive -Path $pathsToPackage -DestinationPath $archivePath -Force

Write-Host "Created release archive at $archivePath"
