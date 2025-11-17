#requires -Version 5.1

[CmdletBinding()]
param(
	[switch]$EditCredentials,
	[switch]$Help,
	[string]$Launch
)

# Greeting shown at script start
Write-Host "`nEDMultiCMDR - multi-CMDR launch helper"
Write-Host "======================================`n"

# Compatibility note: script targets Windows PowerShell 5.1 (no dependency on PowerShell Core/7).
# Avoid PowerShell 7+ only constructs (e.g. C-style ternary ?:). The script performs a runtime check below.
$psver = $PSVersionTable.PSVersion
if ($psver.Major -lt 5 -or ($psver.Major -eq 5 -and $psver.Minor -lt 1)) {
	Write-Warning ("EDMultiCMDR is designed for PowerShell 5.1 or later. Current version: {0}. Some features may not work." -f $psver)
}

if ($Help) {
	Write-Host "Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\EDMultiCMDR.ps1 [options]"
	Write-Host ""
	Write-Host "Options:"
	Write-Host "  -EditCredentials    Open interactive credentials editor"
	Write-Host "  -Launch <selection>  Select accounts non-interactively (e.g. -Launch 1,3-5)"
	Write-Host "  -Verbose            Show diagnostic output (PowerShell common parameter)"
	Write-Host "  -Help               Show this help text"
	Write-Host ""
	Write-Host "Examples:"
	Write-Host "  powershell -File .\EDMultiCMDR.ps1 -EditCredentials"
	Write-Host "  powershell -File .\EDMultiCMDR.ps1 -Launch 1,3-5"
	Write-Host "  powershell -File .\EDMultiCMDR.ps1 -Verbose"
	Write-Host ""
	return
}

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
	}
 catch {
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
		# If frontier, prompt for the launcher profile name to pass to /frontier
		$frontierProfile = $null
		if ($client.ToLower() -eq 'frontier') {
			$profileInput = Read-Host "Frontier profile name (leave blank to use default)"
			if (-not [string]::IsNullOrWhiteSpace($profileInput)) { $frontierProfile = $profileInput }
		}
		# include profile always (empty string when not provided) so all entries have a 'profile' key
		# also prompt for an optional MinEDLauncher path for Frontier installs
		$acct = @{ username = $u; password = $enc; client = $client.ToLower() }
		if ($frontierProfile) { $acct.profile = $frontierProfile } else { $acct.profile = '' }
		$acct.launcherPath = ''
		if ($acct.client -eq 'frontier') {
			$lp = Read-Host "Optional MinEDLauncher path for this account (leave blank to use standard locations)"
			if (-not [string]::IsNullOrWhiteSpace($lp)) { $acct.launcherPath = $lp }
		}
		$accounts += $acct
		Write-Verbose ("Added account: {0} (client: {1})" -f $u, $client)
	}
	if ($accounts.Count -gt 0) {
		Save-EDMultiCredentials -accounts $accounts
	}
	return $accounts
}

function Resolve-AccountSelection {
	param(
		[string]$SelectionText,
		[array]$Accounts
	)

	if (-not $Accounts -or $Accounts.Count -eq 0) { return @() }

	Write-Verbose ("Resolve-AccountSelection invoked. Raw input: '{0}'" -f $SelectionText)

	if ([string]::IsNullOrWhiteSpace($SelectionText)) {
		Write-Verbose "Selection input empty; defaulting to all accounts."
		return [int[]](0..($Accounts.Count - 1))
	}

	$selTrim = $SelectionText.Trim()
	Write-Verbose ("Trimmed selection input: '{0}'" -f $selTrim)
	if ($selTrim.ToLowerInvariant() -eq 'all') {
		Write-Verbose "Selection input equals 'all'; using every account."
		return [int[]](0..($Accounts.Count - 1))
	}

	$idxSet = New-Object System.Collections.Generic.HashSet[int]
	$tokens = $selTrim -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
	if ($tokens.Count -eq 0) {
		Write-Verbose "No tokens parsed from selection input."
		return $null
	}
	Write-Verbose ("Parsed selection tokens: {0}" -f ($tokens -join ', '))

	foreach ($tok in $tokens) {
		$t = $tok.Trim()
		if ($t -match '^(?<a>\d+)\s*-\s*(?<b>\d+)$') {
			try {
				$a = [int]$Matches['a'] - 1
				$b = [int]$Matches['b'] - 1
			}
			catch {
				Write-Warning "Could not parse range token '$t'."
				continue
			}
			if ($a -gt $b) {
				Write-Warning "Ignored range '$t' because start > end."
				continue
			}
			for ($n = $a; $n -le $b; $n++) {
				if ($n -ge 0 -and $n -lt $Accounts.Count) {
					$idxSet.Add($n) | Out-Null
				}
				else {
					Write-Warning ("Index {0} in range '{1}' out of bounds (valid: 1-{2})." -f ($n + 1), $t, $Accounts.Count)
				}
			}
			Write-Verbose ("Range token '{0}' resolved to indices {1}-{2} (0-based)." -f $t, $a, $b)
		}
		elseif ($t -match '^\d+$') {
			try {
				$n = [int]$t - 1
			}
			catch {
				Write-Warning "Could not parse numeric token '$t'."
				continue
			}
			if ($n -ge 0 -and $n -lt $Accounts.Count) {
				$idxSet.Add($n) | Out-Null
				Write-Verbose ("Added index {0} for token '{1}'" -f $n, $t)
			}
			else {
				Write-Warning ("Index '{0}' out of range (valid: 1-{1})." -f $t, $Accounts.Count)
			}
		}
		else {
			Write-Warning "Ignored token '$t' (not a valid number or range)."
		}
	}

	if ($idxSet.Count -gt 0) {
		$result = $idxSet | Sort-Object
		$result = [int[]]$result
		Write-Verbose ("Resolve-AccountSelection returning indices: {0}" -f ($result -join ', '))
		return $result
	}

	return $null
}

function Select-Accounts([array]$accounts) {
	Write-Verbose ("Select-Accounts invoked; accounts.Count = {0}" -f $accounts.Count)
	Write-Host "Available accounts:"
	for ($i = 0; $i -lt $accounts.Count; $i++) {
		$a = $accounts[$i]
		# show profile for frontier accounts if present
		$profileInfo = if ($a.profile) { " profile:`"$($a.profile)`"" } else { "" }
		Write-Host ("[{0}] {1} ({2}{3})" -f ($i + 1), $a.username, $a.client, $profileInfo)
	}

	while ($true) {
		$sel = Read-Host "Select accounts to start (comma/range: e.g. 1,3,5-7) [default: all]"
		Write-Verbose ("User input for selection: '{0}'" -f $sel)
		$indices = Resolve-AccountSelection -SelectionText $sel -Accounts $accounts
		if ($null -ne $indices -and $indices.Count -gt 0) {
			return $indices
		}
		Write-Warning "No valid selection parsed. Try e.g. 'all', '1', '1,3', or '2-4'."
	}
}

function Wait-ForNewEDProcess([int[]]$knownPids, [int]$timeoutSec = 30) {
	$sw = [Diagnostics.Stopwatch]::StartNew()
	while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
		$current = Get-Process -Name 'EliteDangerous64', 'EliteDangerous' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id -ErrorAction SilentlyContinue
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

	# show non-sensitive account details (profile may be empty)
	$profileVal = if ($account.PSObject.Properties['profile']) { $account.profile } else { '' }
	Write-Verbose ("Account details: username={0}, client={1}, profile='{2}'" -f $account.username, $account.client, $profileVal)

	# convert stored encrypted password back to SecureString (DPAPI)
	try {
		$securePass = ConvertTo-SecureString $account.password
		Write-Verbose "Password conversion: success (SecureString obtained)."
	}
 catch {
		Write-Warning "Failed to convert stored password for $($account.username). Skipping."
		return $null
	}
	$pscred = New-Object System.Management.Automation.PSCredential($account.username, $securePass)

	# --- Frontier launcher support ---
	if ($account.client -eq 'frontier') {
		# build candidate locations for MinEdLauncher
		$candidates = @()
		# prefer account-provided launcherPath when present and valid
		$accountLauncherProvided = $false
		$wdFromAccount = $null
		if ($account.PSObject.Properties['launcherPath'] -and -not [string]::IsNullOrWhiteSpace($account.launcherPath)) {
			$accountLauncherProvided = $true
			try {
				$ap = $account.launcherPath
				if (Test-Path $ap) {
					$item = Get-Item -LiteralPath $ap -ErrorAction SilentlyContinue
					if ($null -ne $item -and $item.PSIsContainer) {
						# user supplied a directory -> look for MinEdLauncher.exe inside it
						$cand = Join-Path $ap 'MinEdLauncher.exe'
						if (Test-Path $cand) {
							$candidates += $cand
							$wdFromAccount = $ap
						}
					}
					else {
						# user supplied a file path (assume MinEdLauncher.exe) -> use it and its dir as WD
						$candidates += $ap
						$wdFromAccount = Split-Path $ap
					}
				}
			}
			catch {}
		}
		# standard fallback locations
		$candidates += @(
			"${env:ProgramFiles(x86)}\Elite Dangerous\MinEdLauncher.exe",
			"${env:ProgramFiles(x86)}\Steam\steamapps\common\Elite Dangerous\MinEdLauncher.exe",
			"${env:ProgramFiles}\Elite Dangerous\MinEdLauncher.exe"
		)
		# debug: show initial candidate list (including non-existing) when verbose
		Write-Verbose ("Initial MinEdLauncher candidates (pre-check): {0}" -f ($candidates -join '; '))
		# keep only existing paths (preserves ordering so account-supplied path is tried first)
		$candidates = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
		Write-Verbose ("Available MinEdLauncher candidates (existing): {0}" -f ($candidates -join '; '))
		Write-Verbose ("Account-provided launcherPath present: {0}" -f $accountLauncherProvided)

		if (-not $candidates -or $candidates.Count -eq 0) {
			Write-Warning "Frontier launcher (MinEdLauncher) not found in common locations. Skipping $($account.username)."
			return $null
		}

		$launcherPath = $candidates[0]
		# prefer working directory from account launcherPath when available (directory or file parent)
		if ($wdFromAccount) { $wd = $wdFromAccount } else { $wd = Split-Path $launcherPath }
		# allow optional profile field in credentials JSON to specify the /frontier profile name
		$profileArg = if ($account.profile) { "/frontier $($account.profile)" } else { "/frontier" }
		$arglist = @($profileArg, "/autorun", "/autoquit")

		Write-Host "Starting Frontier launcher ($launcherPath) as $($account.username)..."
		Write-Verbose ("Chosen launcherPath: {0}" -f $launcherPath)
		Write-Verbose ("Working directory: {0}" -f $wd)
		Write-Verbose ("Launcher args array: {0}" -f ($arglist -join '; '))
		Write-Verbose ("Will start Frontier with args: {0}" -f ($arglist -join ' '))

		# Prefer Start-Process -Credential (consistent with Steam handling)
		try {
			Write-Verbose "Attempting Start-Process -Credential for Frontier launcher..."
			$launcherProc = Start-Process -FilePath $launcherPath `
				-ArgumentList $arglist `
				-Credential $pscred `
				-WorkingDirectory $wd `
				-PassThru -ErrorAction Stop
			Write-Verbose ("Start-Process -Credential succeeded for Frontier launcher (PID: {0})." -f $launcherProc.Id)
		}
		catch {
			$errMsg = $_.Exception.Message -or $_.Exception.ToString()
			Write-Warning ("Start-Process -Credential failed for {0}: {1}" -f $account.username, $errMsg)

			# If access denied or similar, try ProcessStartInfo fallback (like Steam branch)
			Write-Verbose "Attempting ProcessStartInfo fallback for Frontier launcher..."
			try {
				$psi = New-Object System.Diagnostics.ProcessStartInfo
				$psi.FileName = $launcherPath
				$psi.Arguments = ($arglist -join ' ')
				$psi.WorkingDirectory = $wd
				$psi.UseShellExecute = $false
				$psi.UserName = $account.username
				$psi.Password = $securePass
				$psi.LoadUserProfile = $true
				# debug: show prepared ProcessStartInfo properties (after assignment)
				Write-Verbose ("ProcessStartInfo prepared: FileName={0}, Arguments={1}, WorkingDirectory={2}, UseShellExecute={3}, UserName={4}, LoadUserProfile={5}" -f $psi.FileName, $psi.Arguments, $psi.WorkingDirectory, $psi.UseShellExecute, $psi.UserName, $psi.LoadUserProfile)

				# Populate environment dictionary safely, if available on this runtime
				$envTarget = $null
				try { if ($null -ne $psi.EnvironmentVariables) { $envTarget = $psi.EnvironmentVariables } } catch {}
				try { if ($null -eq $envTarget -and $null -ne $psi.Environment) { $envTarget = $psi.Environment } } catch {}
				if ($null -ne $envTarget) {
					Write-Verbose "ProcessStartInfo environment dictionary available; populating from current environment."
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
				}
				else {
					Write-Verbose "ProcessStartInfo environment dictionary not available; skipping environment sanitization."
				}

				$launcherProc = [System.Diagnostics.Process]::Start($psi)
				if (-not $launcherProc) { throw "ProcessStartInfo start returned null" }
				Write-Verbose ("ProcessStartInfo fallback succeeded for Frontier launcher (PID: {0})." -f $launcherProc.Id)
			}
			catch {
				$fbMsg = $_.Exception.Message -or $_.Exception.ToString()
				Write-Warning ("Fallback ProcessStartInfo start failed for {0}: {1}" -f $account.username, $fbMsg)
				Write-Warning "Common causes: insufficient privileges to start interactive process as another user, UAC, or Windows policies. Try running the script elevated or create a per-account scheduled task that runs MinEdLauncher under the target account."
				return $null
			}
		}

		# Wait for new Elite process same as Steam branch
		$newPid = Wait-ForNewEDProcess -knownPids $globalKnownPids.Value -timeoutSec 30
		if ($newPid) {
			Write-Host "Detected new Elite: Dangerous process PID $newPid for $($account.username)."
			$globalKnownPids.Value = $globalKnownPids.Value + $newPid
		}
		else {
			Write-Warning "No new Elite: Dangerous process detected within timeout for $($account.username)."
		}

		# we do not terminate the real Frontier launcher process started by MinEDLauncher!

		return $newPid
	}

	# --- Steam ---
	$steamPath = "C:\Program Files (x86)\Steam\steam.exe"
	if (-not (Test-Path $steamPath)) {
		Write-Warning "Steam not found at $steamPath. Skipping $($account.username)."
		return $null
	}

	Write-Host "Starting Steam as $($account.username)..."
	Write-Verbose ("Attempting Start-Process -Credential for Steam: FilePath={0}, Args={1}, WorkingDir={2}" -f $steamPath, $steamArgs, "C:\Program Files (x86)\Steam")

	# First try the simple Start-Process -Credential path
	try {
		$steamArgs = '-silent -gameidlaunch 359320'
		$steamProc = Start-Process -FilePath $steamPath `
			-ArgumentList @('-silent', '-gameidlaunch', '359320') `
			-Credential $pscred `
			-WorkingDirectory "C:\Program Files (x86)\Steam" `
			-PassThru -ErrorAction Stop
		Write-Verbose "Start-Process -Credential succeeded for $($account.username) (PID: $($steamProc.Id))."
	}
 catch {
		$errMsg = $_.Exception.Message -or $_.Exception.ToString()
		# If error matches the duplicate-environment-key problem, attempt a fallback using ProcessStartInfo
		if ($errMsg -match 'Item has already been added' -or $errMsg -match 'WINDIR' -or $errMsg -match 'windir') {
			Write-Verbose "Duplicate environment-key error detected, using fallback ProcessStartInfo start for $($account.username)..."
			try {
				Write-Verbose ("Preparing ProcessStartInfo: FileName={0}, Arguments={1}, WorkingDirectory={2}" -f $steamPath, '-silent -gameidlaunch 359320', "C:\Program Files (x86)\Steam")
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
				}
				else {
					Write-Verbose "ProcessStartInfo environment dictionary not available on this runtime; skipping environment sanitization."
				}

				$steamProc = [System.Diagnostics.Process]::Start($psi)
				if (-not $steamProc) { throw "ProcessStartInfo start returned null" }
				Write-Verbose ("ProcessStartInfo fallback succeeded for {0} (PID: {1})" -f $account.username, $steamProc.Id)
			}
			catch {
				Write-Warning "Fallback ProcessStartInfo start failed for $($account.username): $($_.Exception.Message)"
				return $null
			}
		}
		else {
			Write-Warning "Failed to start Steam for $($account.username): $errMsg"
			return $null
		}
	}

	# Wait for new Elite process
	$newPid = Wait-ForNewEDProcess -knownPids $globalKnownPids.Value -timeoutSec 30
	if ($newPid) {
		Write-Host "Detected new Elite: Dangerous process PID $newPid for $($account.username)."
		$globalKnownPids.Value = $globalKnownPids.Value + $newPid
	}
 else {
		Write-Warning "No new Elite: Dangerous process detected within timeout for $($account.username)."
	}

	# terminate Steam process we started (if still running)
	try {
		if ($steamProc -and ($steamProc.HasExited -eq $false)) {
			if ($steamProc -is [System.Diagnostics.Process]) {
				$steamProc.Kill()
			}
			else {
				try { Stop-Process -Id $steamProc.Id -Force -ErrorAction SilentlyContinue } catch {}
			}
			$stoppedPid = $null
			try { $stoppedPid = $steamProc.Id } catch {}
			if ($stoppedPid) {
				Write-Host "Stopped Steam process (PID $stoppedPid) started for $($account.username)."
			}
			else {
				Write-Host "Stopped Steam process started for $($account.username)."
			}
		}
	}
 catch {
		Write-Warning "Could not stop Steam process PID $($steamProc.Id): $($_.Exception.Message)"
	}

	return $newPid
}

function Edit-EDMultiCredentials {
	<#
    Interactive editor for stored credentials.
    Supports: list, add, edit <n>, remove <n>, save, quit
    #>
	while ($true) {
		$accounts = Get-EDMultiCredentials
		if (-not $accounts) { $accounts = @() }

		Write-Host "`nStored accounts:"
		for ($i = 0; $i -lt $accounts.Count; $i++) {
			$a = $accounts[$i]
			$prof = if ($a.profile) { " profile=`"$($a.profile)`"" } else { "" }
			Write-Host ("[{0}] {1} ({2}{3})" -f ($i + 1), $a.username, $a.client, $prof)
		}
		Write-Host ""
		$cmd = Read-Host "Command: (a)dd, (e)dit <number>, (r)emove <number>, (s)ave, (q)uit"
		if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
		$parts = $cmd.Trim() -split '\s+'
		switch ($parts[0].ToLower()) {
			'a' {
				$u = Read-Host "Username (email / local username)"
				if ([string]::IsNullOrWhiteSpace($u)) { Write-Warning "Username required."; continue }
				$p = Read-Host "Password (input hidden)" -AsSecureString
				$enc = $p | ConvertFrom-SecureString
				$client = Read-Host "Client type (steam/frontier/epic) [default: steam]"
				if ([string]::IsNullOrWhiteSpace($client)) { $client = 'steam' }
				# always ensure a 'profile' key exists; set frontier profile when provided, otherwise empty
				$acct = @{ username = $u; password = $enc; client = $client.ToLower() }
				if ($client.ToLower() -eq 'frontier') {
					$profInput = Read-Host "Frontier profile name (leave blank to use default)"
					if (-not [string]::IsNullOrWhiteSpace($profInput)) { $acct.profile = $profInput } else { $acct.profile = '' }
					$lp = Read-Host "Optional MinEDLauncher path for this account (leave blank to use standard locations)"
					if (-not [string]::IsNullOrWhiteSpace($lp)) { $acct.launcherPath = $lp } else { $acct.launcherPath = '' }
				}
				else {
					$acct.profile = ''
					$acct.launcherPath = ''
				}
				$accounts += $acct
				Save-EDMultiCredentials -accounts $accounts
				Write-Host "Added account for $u and saved."
			}
			'e' {
				if ($parts.Count -lt 2 -or -not [int]::TryParse($parts[1], [ref]$null)) {
					Write-Warning "Usage: e <number>"
					continue
				}
				$idx = [int]$parts[1] - 1
				if ($idx -lt 0 -or $idx -ge $accounts.Count) { Write-Warning "Index out of range."; continue }
				$a = $accounts[$idx]
				$nu = Read-Host "Username [$($a.username)]"
				if (-not [string]::IsNullOrWhiteSpace($nu)) { $a.username = $nu }
				$chg = Read-Host "Change password? (y/N)"
				if ($chg -match '^[yY]') {
					$np = Read-Host "Password (input hidden)" -AsSecureString
					$a.password = $np | ConvertFrom-SecureString
				}
				$nc = Read-Host "Client [$($a.client)]"
				if (-not [string]::IsNullOrWhiteSpace($nc)) { $a.client = $nc.ToLower() }
				# robustly ensure 'profile' and 'launcherPath' exist for all accounts:
				$current = if ($a.PSObject.Properties['profile']) { $a.profile } else { '' }
				$currentLauncher = if ($a.PSObject.Properties['launcherPath']) { $a.launcherPath } else { '' }
				if ($a.client -eq 'frontier') {
					$display = if ($current -ne '') { $current } else { 'none' }
					$nprof = Read-Host ("Profile name [{0}] (leave blank to keep)" -f $display)
					$displayLauncher = if ($currentLauncher -ne '') { $currentLauncher } else { 'none' }
					$nlauncher = Read-Host ("MinEDLauncher path [{0}] (leave blank to keep)" -f $displayLauncher)
					if (-not [string]::IsNullOrWhiteSpace($nprof)) {
						if ($a.PSObject.Properties['profile']) {
							$a.profile = $nprof
						}
						else {
							$a | Add-Member -NotePropertyName 'profile' -NotePropertyValue $nprof -Force
						}
					}
					elseif (-not $a.PSObject.Properties['profile']) {
						# create empty profile property if missing
						$a | Add-Member -NotePropertyName 'profile' -NotePropertyValue '' -Force
					}
					if (-not [string]::IsNullOrWhiteSpace($nlauncher)) {
						if ($a.PSObject.Properties['launcherPath']) {
							$a.launcherPath = $nlauncher
						}
						else {
							$a | Add-Member -NotePropertyName 'launcherPath' -NotePropertyValue $nlauncher -Force
						}
					}
					elseif (-not $a.PSObject.Properties['launcherPath']) {
						$a | Add-Member -NotePropertyName 'launcherPath' -NotePropertyValue '' -Force
					}
				}
				else {
					# when switching to non-frontier (e.g. steam), keep a profile key but set empty
					if ($a.PSObject.Properties['profile']) {
						$a.profile = ''
					}
					else {
						$a | Add-Member -NotePropertyName 'profile' -NotePropertyValue '' -Force
					}
					# ensure launcherPath present but empty for non-frontier
					if ($a.PSObject.Properties['launcherPath']) {
						$a.launcherPath = ''
					}
					else {
						$a | Add-Member -NotePropertyName 'launcherPath' -NotePropertyValue '' -Force
					}
				}
				$accounts[$idx] = $a
				Save-EDMultiCredentials -accounts $accounts
				Write-Host "Edited entry $($idx+1) and saved."
			}
			'r' {
				if ($parts.Count -lt 2 -or -not [int]::TryParse($parts[1], [ref]$null)) {
					Write-Warning "Usage: r <number>"
					continue
				}
				$idx = [int]$parts[1] - 1
				if ($idx -lt 0 -or $idx -ge $accounts.Count) { Write-Warning "Index out of range."; continue }
				$confirm = Read-Host "Remove account $($accounts[$idx].username)? (y/N)"
				if ($confirm -match '^[yY]') {
					$accounts = $accounts | Where-Object { $_ -ne $accounts[$idx] }
					Save-EDMultiCredentials -accounts $accounts
					Write-Host "Removed entry $($idx+1) and saved."
				}
			}
			's' {
				Save-EDMultiCredentials -accounts $accounts
				Write-Host "Saved credentials."
				return
			}
			'q' {
				$confirm = Read-Host "Quit without saving? (y/N)"
				if ($confirm -match '^[yY]') { return }
			}
			default {
				Write-Warning "Unknown command."
			}
		}
	}
}

# If user requested only to edit credentials, do so and exit
if ($EditCredentials) {
	Edit-EDMultiCredentials
	return
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

$selectedIdx = $null
if ($PSBoundParameters.ContainsKey('Launch')) {
	Write-Verbose ("-Launch parameter specified: '{0}'" -f $Launch)
	$selectedIdx = Resolve-AccountSelection -SelectionText $Launch -Accounts $accounts
	if ($null -eq $selectedIdx -or $selectedIdx.Count -eq 0) {
		Write-Error "Could not parse -Launch selection. Use values like 'all', '1', '1,3', or '2-4'."
		exit 1
	}
}
else {
	$selectedIdx = Select-Accounts -accounts $accounts
}

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
$existingPids = Get-Process -Name 'EliteDangerous64', 'EliteDangerous' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id -ErrorAction SilentlyContinue
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
	}
 else {
		Write-Host " - $($r.username): no new Elite instance detected / skipped"
	}
}
