param()

function Initialize-CredentialStore {
    # replaced: no external module required; ensure storage directory exists and set file path
    $storeDir = Join-Path $env:LOCALAPPDATA 'EDMultiCMDR'
    if (-not (Test-Path $storeDir)) { New-Item -Path $storeDir -ItemType Directory -Force | Out-Null }
    $script:EDMultiCredFile = Join-Path $storeDir 'credentials.json'
}

function Get-EDMultiCredentials {
    # read JSON file if present, return array of accounts (password is stored encrypted)
    if (-not (Test-Path $script:EDMultiCredFile)) { return $null }
    try {
        $json = Get-Content -Path $script:EDMultiCredFile -Raw -ErrorAction Stop
        $obj = $json | ConvertFrom-Json -ErrorAction Stop
        return $obj.EDMultiCMDR
    } catch {
        Write-Warning "Could not read credentials file (corrupt JSON?): $($_.Exception.Message)"
        return $null
    }
}

function Save-EDMultiCredentials([array]$accounts) {
    # accounts contain password as encrypted string (ConvertFrom-SecureString)
    $payload = @{ EDMultiCMDR = $accounts } | ConvertTo-Json -Depth 5
    $payload | Out-File -FilePath $script:EDMultiCredFile -Encoding UTF8 -Force
}

function New-EDMultiAccounts {
    Write-Host "No stored accounts found. Create accounts now."
    $accounts = @()
    while ($true) {
        $u = Read-Host "Username (email / local username) [leave blank to stop]"
        if ([string]::IsNullOrWhiteSpace($u)) { break }
        # read as SecureString and store encrypted string (DPAPI) in JSON
        $p = Read-Host "Password (input hidden)" -AsSecureString
        $enc = $p | ConvertFrom-SecureString
        $client = Read-Host "Client type (steam/frontier/epic) [default: steam]"
        if ([string]::IsNullOrWhiteSpace($client)) { $client = "steam" }
        $accounts += @{ username = $u; password = $enc; client = $client.ToLower() }
    }
    if ($accounts.Count -gt 0) {
        Save-EDMultiCredentials -accounts $accounts
    }
    return $accounts
}

function Select-Accounts([array]$accounts) {
    Write-Host "Available accounts:"
    for ($i=0; $i -lt $accounts.Count; $i++) {
        $a = $accounts[$i]
        Write-Host ("[{0}] {1} ({2})" -f ($i+1), $a.username, $a.client)
    }
    $sel = Read-Host "Select accounts to start (comma-separated indices) [default: all]"

    if ([string]::IsNullOrWhiteSpace($sel)) {
        return 0..($accounts.Count-1)
    }

    $selTrim = $sel.Trim().ToLowerInvariant()
    if ($selTrim -eq 'all') {
        return 0..($accounts.Count-1)
    }

    $idx = $sel -split '[, ]+' `
        | Where-Object { $_ -match '^\d+$' } `
        | ForEach-Object { [int]$_ - 1 } `
        | Where-Object { $_ -ge 0 -and $_ -lt $accounts.Count } `
        | Select-Object -Unique

    if (-not $idx) { return @() }
    if ($idx -is [array]) { return $idx }
    return ,$idx
}

function Wait-ForNewEDProcess([int[]]$knownPids, [int]$timeoutSec = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        $current = Get-Process -Name 'EliteDangerous64','EliteDangerous' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id -ErrorAction SilentlyContinue
        $new = $current | Where-Object { $_ -and ($knownPids -notcontains $_) }
        if ($new) {
            return $new[0]
        }
        Start-Sleep -Seconds 1
    }
    return $null
}

function Start-EDLaunchForAccount($account, [ref]$globalKnownPids) {
    if ($account.client -ne 'steam') {
        Write-Host "Skipping $($account.username): unsupported client '$($account.client)'."
        return $null
    }
    $steamPath = "C:\Program Files (x86)\Steam\steam.exe"
    if (-not (Test-Path $steamPath)) {
        Write-Warning "Steam not found at $steamPath. Skipping $($account.username)."
        return $null
    }

    # convert stored encrypted password back to SecureString (DPAPI)
    try {
        $securePass = ConvertTo-SecureString $account.password
    } catch {
        Write-Warning "Failed to convert stored password for $($account.username). Skipping."
        return $null
    }
    $pscred = New-Object System.Management.Automation.PSCredential($account.username, $securePass)

    Write-Host "Starting Steam as $($account.username)..."
    try {
        # Removed -WorkingDirectory to avoid environment-key duplication ("WINDIR"/"windir") when using -Credential
        $steamProc = Start-Process -FilePath $steamPath -ArgumentList @('-silent','-gameidlaunch','359320') -Credential $pscred -PassThru -ErrorAction Stop
    } catch {
        Write-Warning "Failed to start Steam for $($account.username): $_"
        return $null
    }

    $newPid = Wait-ForNewEDProcess -knownPids $globalKnownPids.Value -timeoutSec 30
    if ($newPid) {
        Write-Host "Detected new Elite: Dangerous process PID $newPid for $($account.username)."
        # add to known list so subsequent launches don't detect the same PID as new
        $globalKnownPids.Value = $globalKnownPids.Value + $newPid
    } else {
        Write-Warning "No new Elite: Dangerous process detected within timeout for $($account.username)."
    }

    # terminate Steam process we started (if still running)
    if ($steamProc -and ($steamProc.HasExited -eq $false)) {
        try {
            Stop-Process -Id $steamProc.Id -Force -ErrorAction SilentlyContinue
            Write-Host "Stopped Steam process (PID $($steamProc.Id)) started for $($account.username)."
        } catch {
            Write-Warning "Could not stop Steam process PID $($steamProc.Id): $_"
        }
    }

    return $newPid
}

# --- main flow ---
Initialize-CredentialStore

$accounts = Get-EDMultiCredentials
if (-not $accounts -or $accounts.Count -eq 0) {
    $accounts = New-EDMultiAccounts
    if (-not $accounts -or $accounts.Count -eq 0) {
        Write-Error "No accounts configured. Exiting."
        exit 1
    }
}

$selectedIdx = Select-Accounts -accounts $accounts
if (-not $selectedIdx -or $selectedIdx.Count -eq 0) {
    Write-Error "No accounts selected. Exiting."
    exit 1
}

# gather existing Elite: Dangerous PIDs
$existingPids = Get-Process -Name 'EliteDangerous64','EliteDangerous' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id -ErrorAction SilentlyContinue
if (-not $existingPids) { $existingPids = @() }
# keep a mutable reference for known PIDs
$knownPidsRef = [ref]$existingPids

$results = @()
foreach ($i in $selectedIdx) {
    $acc = $accounts[$i]
    $edPid = Start-EDLaunchForAccount -account $acc -globalKnownPids $knownPidsRef
    $results += [PSCustomObject]@{ username = $acc.username; client = $acc.client; edpid = $edPid }
}

Write-Host "`nSummary:"
foreach ($r in $results) {
    if ($r.edpid) {
        Write-Host " - $($r.username): started Elite PID $($r.edpid)"
    } else {
        Write-Host " - $($r.username): no new Elite instance detected / skipped"
    }
}