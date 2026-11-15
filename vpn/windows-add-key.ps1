#Requires -Version 5.1
param([string]$From)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-install.ps1')

function Get-RcVpnComputerName {
    $name = [Net.Dns]::GetHostName().ToLowerInvariant()
    if ($name -notmatch '^[a-z0-9][a-z0-9-]*$' -or $env:USERNAME -notmatch '^[\w.-]+$') {
        throw "Rename this computer or account to use only letters, digits and hyphens: $name, $env:USERNAME."
    }
    $name
}

function Get-RcVpnOwnKey {
    $key = Join-Path $env:USERPROFILE '.ssh\id_ed25519'
    if (-not (Test-Path -LiteralPath $key)) {
        $null = [IO.Directory]::CreateDirectory((Split-Path $key))
        Write-Host 'Creating an SSH key for this laptop. Choose a passphrase for it.'
        & ssh-keygen.exe -q -t ed25519 -a 100 -C "$env:USERNAME@$(Get-RcVpnComputerName)" -f $key
        if ($LASTEXITCODE -ne 0) { throw "ssh-keygen failed with exit code $LASTEXITCODE." }
        Set-Service -Name ssh-agent -StartupType Automatic
        Start-Service -Name ssh-agent
        Write-Host 'Adding the key to ssh-agent so you only type the passphrase once.'
        & ssh-add.exe $key
        if ($LASTEXITCODE -ne 0) { throw "ssh-add failed with exit code $LASTEXITCODE." }
    }
    if ([IO.File]::ReadAllText("$key.pub") -notmatch '^\s*([\w@.-]+)\s+([A-Za-z0-9+/=]+)') { throw "$key.pub is not a public key." }
    "$($Matches[1]) $($Matches[2])"
}

function Set-RcVpnSshAlias {
    param([string]$Alias, [string]$User)
    $path = Join-Path $env:USERPROFILE '.ssh\config'
    $lines = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $path) { $lines.AddRange([IO.File]::ReadAllLines($path)) }
    $before = $lines -join "`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*Host\s+$([regex]::Escape($Alias))\s*$") { $start = $i; break }
    }
    if ($start -lt 0) {
        if ($lines.Count -and $lines[$lines.Count - 1].Trim()) { $lines.Add('') }
        $start = $lines.Count
        $lines.Add("Host $Alias")
    }
    $end = $start + 1
    while ($end -lt $lines.Count -and $lines[$end] -notmatch '^\s*(Host|Match)\s') { $end++ }
    for ($i = $end - 1; $i -gt $start; $i--) {
        if ($lines[$i] -match '^\s*(HostName|User)\s') { $lines.RemoveAt($i) }
    }
    $lines.Insert($start + 1, "    User $User")
    $lines.Insert($start + 1, "    HostName $Alias")
    if (($lines -join "`n") -cne $before) {
        $null = [IO.Directory]::CreateDirectory((Split-Path $path))
        [IO.File]::WriteAllLines($path, $lines)
        Write-Host "Saved SSH alias $Alias for $User@$Alias."
    }
}

function Get-RcVpnHomeAddress {
    $route = Get-NetRoute -DestinationPrefix $RcVpnHomeNetwork -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -ne $RcVpnTunnel } | Select-Object -First 1
    if ($route) {
        $network = Get-NetConnectionProfile -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
        [pscustomobject]@{
            Address = @(Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4)[0].IPAddress
            Name = $network.Name
            Category = "$($network.NetworkCategory)"
        }
    }
}

function Get-RcVpnRemoteCommand {
    param([string]$OwnKey, [string]$Name, [string]$Address, [bool]$InstallKey)
    $remote = @('RC_PRINT_KEYS=1')
    if ($InstallKey) { $remote += "RC_KEY='$OwnKey $env:USERNAME@$Name'" }
    if ($Address) { $remote += "RC_ALIAS_NAME='$Name'", "RC_ALIAS_ADDRESS='$Address'", "RC_ALIAS_USER='$env:USERNAME'" }
    $remote += [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'remote-trust.sh'))
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((($remote -join "`n") -replace "`r", '')))
    "echo $encoded | base64 -d | sh"
}

function Read-RcVpnRemoteKeys {
    param([string]$Target, [string]$OwnKey)
    $alias = $Target
    if ($Target.Contains('@')) {
        $user, $alias = $Target -split '@', 2
        Set-RcVpnSshAlias $alias $user
    }
    $name = Get-RcVpnComputerName
    $lan = Get-RcVpnHomeAddress
    $address = $lan.Address
    if (-not $address) {
        Write-Host "This laptop is not on the home network ($RcVpnHomeNetwork), so $alias will not get an SSH alias for it."
    } elseif ($lan.Category -ne 'Private') {
        Write-Host "Windows treats the network '$($lan.Name)' as $($lan.Category), so it blocks SSH from $alias. If it is your home network, mark it Private in Settings > Network & internet."
    }
    Write-Host "Reading the keys trusted by $alias."
    $lines = @(& ssh -o BatchMode=yes $alias (Get-RcVpnRemoteCommand $OwnKey $name $address $false))
    if ($LASTEXITCODE -eq 255) {
        Write-Host "Key login to $alias failed. Log in with its password to install this laptop's key there."
        $lines = @(& ssh $alias (Get-RcVpnRemoteCommand $OwnKey $name $address $true))
    }
    if ($LASTEXITCODE -ne 0) { throw "ssh $alias failed with exit code $LASTEXITCODE." }
    if ($address) { Write-Host "From $alias, reach this laptop with: ssh $name" }
    $lines
}

function Read-RcVpnPastedKeys {
    Write-Host 'Paste public keys, one per line (from ~/.ssh/id_ed25519.pub on each device), then press Enter on an empty line.'
    while ($line = Read-Host) { $line }
}

function Add-RcVpnSshKey {
    param([string[]]$Lines, [string]$Exclude)
    $path = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
    $keys = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' }
    $added = 0
    foreach ($line in $Lines) {
        $text = "$line".Trim()
        if (-not $text -or $text.StartsWith('#')) { continue }
        $fields = $text -split '\s+'
        $name = ($fields | Select-Object -Skip 2) -join ' '
        if ($fields.Count -lt 2 -or $fields[0] -cnotmatch '^(ssh-|ecdsa-|sk-)[A-Za-z0-9@._-]+$' -or $fields[1] -cnotmatch '^[A-Za-z0-9+/]+=*$') {
            Write-Warning 'Skipped a line that is not a plain public key, such as one with command= or from= options.'
        } elseif ($Exclude -and $fields[1] -ceq $Exclude) {
            Write-Output "Skipped this laptop's own key: $name"
        } elseif ($keys.Contains($fields[1])) {
            Write-Output "Already authorized: $name"
        } else {
            if ($keys -and -not $keys.EndsWith("`n")) { $keys += "`n" }
            $keys += "$text`n"
            $added++
            Write-Output "Added: $name"
        }
    }
    if ($added) { [IO.File]::WriteAllText($path, $keys, [Text.UTF8Encoding]::new($false)) }
    if (Test-Path -LiteralPath $path) {
        & icacls.exe $path /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "icacls failed with exit code $LASTEXITCODE." }
    }
    $address = Get-RcVpnAddress
    if (-not $address) { $address = '<VPN address>' }
    Write-Output "Added $added key(s). From those devices, connect with: ssh $env:USERNAME@$address"
}

function Add-RcVpnTrustedKeys {
    param([string]$From)
    if ($From) {
        $ownKey = Get-RcVpnOwnKey
        Add-RcVpnSshKey @(Read-RcVpnRemoteKeys $From $ownKey) -Exclude ($ownKey -split ' ')[1]
    } else {
        Add-RcVpnSshKey @(Read-RcVpnPastedKeys)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($From -and $From -cnotmatch '^([A-Za-z0-9_][A-Za-z0-9_.-]*@)?[A-Za-z0-9_][A-Za-z0-9_.-]*$') {
        throw "Give an SSH alias or user@host, such as user@server: $From"
    }
    if (Test-RcVpnAdministrator) { Add-RcVpnTrustedKeys $From } else { Start-RcVpnElevated $PSCommandPath $From }
}
