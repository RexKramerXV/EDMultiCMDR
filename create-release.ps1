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

$excluded = @('.git', 'dist', '.DS_Store')
$pathsToPackage = Get-ChildItem -Path $repoRoot -Force |
    Where-Object { $excluded -notcontains $_.Name } |
    ForEach-Object { $_.FullName }

if (-not $pathsToPackage) {
    throw "Nothing to package from $repoRoot"
}

Compress-Archive -Path $pathsToPackage -DestinationPath $archivePath -Force

Write-Host "Created release archive at $archivePath"
