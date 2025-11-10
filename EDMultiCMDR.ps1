[CmdletBinding()]
param()

# Greeting shown at script start
Write-Host "`nEDMultiCMDR - multi-CMDR launch helper"
Write-Host "======================================`n"

function Initialize-CredentialStore {
    # replaced: no external module required; ensure storage directory exists and set file path
    $storeDir = Join-Path $env:LOCALAPPDATA 'EDMultiCMDR'
    if (-not (Test-Path $storeDir)) { New-Item -Path $storeDir -ItemType Directory -Force | Out-Null }
    $script:EDMultiCredFile = Join-Path $storeDir 'credentials.json'
    Write-Verbose "Credential store initialized. Credentials file: $script:EDMultiCredFile"
}

function Get-EDMultiCredentials {
    # read JSON file if present, return array of accounts (password is stored encrypted)
    if (-not (Test-Path $script:EDMultiCredFile)) { return $null }
    try {
        $json = Get-Content -Path $script:EDMultiCredFile -Raw -ErrorAction Stop
        Write-Verbose "Read credentials file content (length: $($json.Length) chars)."
        $obj = $json | ConvertFrom-Json -ErrorAction Stop
        Write-Verbose ("Parsed JSON. Entries present: {0}" -f ($obj.EDMultiCMDR.Count -as [int]))
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
    Write-Verbose ("Saved {0} account(s) to {1}" -f $accounts.Count, $script:EDMultiCredFile)
}

function New-EDMultiAccounts {
    Write-Host "No stored accounts found. Create accounts now."
    Write-Verbose "Interactive account creation started."
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
        Write-Verbose ("Added account: {0} (client: {1})" -f $u, $client)
    }
    if ($accounts.Count -gt 0) {
        Save-EDMultiCredentials -accounts $accounts
    }
    return $accounts
}

function Select-Accounts([array]$accounts) {
    Write-Verbose ("Select-Accounts invoked; accounts.Count = {0}" -f $accounts.Count)
    Write-Host "Available accounts:"
    for ($i = 0; $i -lt $accounts.Count; $i++) {
        $a = $accounts[$i]
        Write-Host ("[{0}] {1} ({2})" -f ($i + 1), $a.username, $a.client)
    }

    while ($true) {
        $sel = Read-Host "Select accounts to start (comma/range: e.g. 1,3,5-7) [default: all]"
        Write-Verbose ("User input for selection: '{0}'" -f $sel)
        if ([string]::IsNullOrWhiteSpace($sel)) {
            Write-Verbose "No input given; defaulting to all accounts."
            return [int[]](0..($accounts.Count - 1))
        }

        $selTrim = $sel.Trim()
        Write-Verbose ("Trimmed input: '{0}'" -f $selTrim)
        if ($selTrim.ToLowerInvariant() -eq 'all') {
            Write-Verbose "User entered 'all' (case-insensitive). Returning all indices."
            return [int[]](0..($accounts.Count - 1))
        }

        $idxSet = New-Object System.Collections.Generic.HashSet[int]

        # Split on commas; accept tokens like "2" or "2-5". Tolerate spaces.
        $tokens = $selTrim -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        Write-Verbose ("Parsed tokens: {0}" -f ($tokens -join ', '))

        foreach ($tok in $tokens) {
            $t = $tok.Trim()
            if ($t -match '^(?<a>\d+)\s*-\s*(?<b>\d+)$') {
                # range token (1-based input)
                try {
                    $a = [int]$Matches['a'] - 1
                    $b = [int]$Matches['b'] - 1
                } catch {
                    Write-Warning "Could not parse range token '$t'."
                    continue
                }
                if ($a -gt $b) {
                    Write-Warning "Ignored range '$t' because start > end."
                    continue
                }
                for ($n = $a; $n -le $b; $n++) {
                    if ($n -ge 0 -and $n -lt $accounts.Count) { $idxSet.Add($n) | Out-Null }
                }
                Write-Verbose ("Interpreted range token '{0}' -> {1}-{2}" -f $t, $a, $b)
            } elseif ($t -match '^\d+$') {
                # single number token (1-based input)
                try {
                    $n = [int]$t - 1
                } catch {
                    Write-Warning "Could not parse numeric token '$t'."
                    continue
                }
                if ($n -ge 0 -and $n -lt $accounts.Count) {
                    $idxSet.Add($n) | Out-Null
                    Write-Verbose ("Added index {0} for token '{1}'" -f $n, $t)
                } else {
                    Write-Warning ("Index '{0}' out of range (valid: 1-{1})." -f $t, $accounts.Count)
                }
            } else {
                Write-Warning "Ignored token '$t' (not a valid number or range)."
            }
        }

        if ($idxSet.Count -gt 0) {
            $result = $idxSet | Sort-Object
            $result = [int[]]$result
            Write-Verbose ([string]::Format("Returning selected indices (0-based): {0}", ($result -join ', ')))
            return $result
        }

        Write-Warning "No valid selection parsed. Try e.g. 'all', '1', '1,3', or '2-4'."
    }
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
    Write-Verbose ("Start-EDLaunchForAccount: account={0}, client={1}" -f $account.username, $account.client)
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

    # First try the simple Start-Process -Credential path
    try {
        $steamProc = Start-Process -FilePath $steamPath `
            -ArgumentList @('-silent','-gameidlaunch','359320') `
            -Credential $pscred `
            -WorkingDirectory "C:\Program Files (x86)\Steam" `
            -PassThru -ErrorAction Stop
        Write-Verbose "Start-Process -Credential succeeded for $($account.username) (PID: $($steamProc.Id))."
    } catch {
        $errMsg = $_.Exception.Message -or $_.Exception.ToString()
        # If error matches the duplicate-environment-key problem, attempt a fallback using ProcessStartInfo
        if ($errMsg -match 'Item has already been added' -or $errMsg -match 'WINDIR' -or $errMsg -match 'windir') {
            Write-Verbose "Duplicate environment-key error detected, using fallback ProcessStartInfo start for $($account.username)..."
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $steamPath
                $psi.Arguments = '-silent -gameidlaunch 359320'
                $psi.WorkingDirectory = "C:\Program Files (x86)\Steam"
                $psi.UseShellExecute = $false
                $psi.UserName = $account.username
                $psi.Password = $securePass
                $psi.LoadUserProfile = $true

                # Robustly find the environment dictionary on this runtime and populate it safely.
                $envTarget = $null
                try { if ($null -ne $psi.EnvironmentVariables) { $envTarget = $psi.EnvironmentVariables } } catch {}
                try { if ($null -eq $envTarget -and $null -ne $psi.Environment) { $envTarget = $psi.Environment } } catch {}

                if ($null -ne $envTarget) {
                    try { $envTarget.Clear() } catch {}
                    $added = @{ }
                    $currentEnv = [System.Environment]::GetEnvironmentVariables()
                    foreach ($k in $currentEnv.Keys) {
                        $kstr = [string]$k
                        $upper = $kstr.ToUpperInvariant()
                        if (-not $added.ContainsKey($upper)) {
                            try { $envTarget[$kstr] = $currentEnv[$k] } catch {}
                            $added[$upper] = $true
                        }
                    }
                } else {
                    Write-Verbose "ProcessStartInfo environment dictionary not available on this runtime; skipping environment sanitization."
                }

                $steamProc = [System.Diagnostics.Process]::Start($psi)
                if (-not $steamProc) { throw "ProcessStartInfo start returned null" }
                Write-Verbose "ProcessStartInfo fallback succeeded for $($account.username) (PID: $($steamProc.Id))."
            } catch {
                Write-Warning "Fallback ProcessStartInfo start failed for $($account.username): $($_.Exception.Message)"
                return $null
            }
        } else {
            Write-Warning "Failed to start Steam for $($account.username): $errMsg"
            return $null
        }
    }

    # Wait for new Elite process
    $newPid = Wait-ForNewEDProcess -knownPids $globalKnownPids.Value -timeoutSec 30
    if ($newPid) {
        Write-Host "Detected new Elite: Dangerous process PID $newPid for $($account.username)."
        $globalKnownPids.Value = $globalKnownPids.Value + $newPid
    } else {
        Write-Warning "No new Elite: Dangerous process detected within timeout for $($account.username)."
    }

    # terminate Steam process we started (if still running)
    try {
        if ($steamProc -and ($steamProc.HasExited -eq $false)) {
            if ($steamProc -is [System.Diagnostics.Process]) {
                $steamProc.Kill()
            } else {
                try { Stop-Process -Id $steamProc.Id -Force -ErrorAction SilentlyContinue } catch {}
            }
            $stoppedPid = $null
            try { $stoppedPid = $steamProc.Id } catch {}
            if ($stoppedPid) {
                Write-Host "Stopped Steam process (PID $stoppedPid) started for $($account.username)."
            } else {
                Write-Host "Stopped Steam process started for $($account.username)."
            }
        }
    } catch {
        Write-Warning "Could not stop Steam process PID $($steamProc.Id): $($_.Exception.Message)"
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
# >>> Ensure array <<<
$accounts = @($accounts)

$selectedIdx = Select-Accounts -accounts $accounts
$selectedIdx = @($selectedIdx)   # ensure array semantics even if single value
Write-Verbose ("Selected indices after wrapping: {0}" -f ($selectedIdx -join ', '))
if ($null -eq $selectedIdx -or $selectedIdx.Count -eq 0) {
    Write-Error "No accounts selected. Exiting."
    exit 1
}

# small launch-time diagnostic: show which credential will be used before starting
foreach ($i in $selectedIdx) {
    $acc = $accounts[$i]
    Write-Verbose ("About to launch for index {0} -> username: {1}, client: {2}" -f $i, $acc.username, $acc.client)
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