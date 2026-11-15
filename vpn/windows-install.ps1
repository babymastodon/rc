#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$RcVpnSettings = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'settings'))) {
    if ($line -match '^(\w+)=(.*)$') { $RcVpnSettings[$Matches[1]] = $Matches[2].Trim() }
}
$RcVpnTunnel = $RcVpnSettings.RC_VPN_TUNNEL
$RcVpnHomeNetwork = $RcVpnSettings.RC_VPN_HOME_NETWORK
$RcVpnWireGuard = Join-Path $env:ProgramFiles 'WireGuard\wireguard.exe'
$RcVpnStore = Join-Path $env:ProgramFiles 'WireGuard\Data\Configurations'
$RcVpnStoredConfig = Join-Path $RcVpnStore "$RcVpnTunnel.conf.dpapi"
$RcVpnSshd = Join-Path $env:SystemRoot 'System32\OpenSSH\sshd.exe'

function Test-RcVpnAdministrator {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-RcVpnElevated {
    param([string]$Path, [string]$Argument)
    $shell = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else {
        Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }
    $command = "-NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File `"$Path`""
    if ($Argument) { $command += " `"$Argument`"" }
    Write-Output 'Continuing in a new administrator window.'
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process -FilePath wt.exe -Verb RunAs -ArgumentList "`"$shell`" $command"
    } else {
        Start-Process -FilePath $shell -Verb RunAs -ArgumentList $command
    }
}

function Invoke-RcVpnWireGuard {
    param([string]$Arguments)
    $process = Start-Process -FilePath $RcVpnWireGuard -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "wireguard.exe $Arguments failed with exit code $($process.ExitCode)." }
}

function Wait-RcVpn {
    param([scriptblock]$Condition, [string]$Message)
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (& $Condition)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw $Message }
        Start-Sleep -Milliseconds 500
    }
}

function Test-RcVpnTunnelUp {
    "$((Get-NetAdapter -Name $RcVpnTunnel -ErrorAction SilentlyContinue).Status)" -eq 'Up'
}

function Get-RcVpnAddress {
    if (Test-RcVpnTunnelUp) { @(Get-NetIPAddress -InterfaceAlias $RcVpnTunnel -AddressFamily IPv4)[0].IPAddress }
}

function Set-RcVpnPrivate {
    Wait-RcVpn { Get-NetConnectionProfile -InterfaceAlias $RcVpnTunnel -ErrorAction SilentlyContinue } `
        'Windows did not detect the rc-vpn network.'
    Set-NetConnectionProfile -InterfaceAlias $RcVpnTunnel -NetworkCategory Private
}

function Install-RcVpnWireGuard {
    if (-not (Test-Path -LiteralPath $RcVpnWireGuard)) {
        & winget.exe install --id WireGuard.WireGuard --exact --source winget --silent `
            --accept-source-agreements --accept-package-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "winget failed with exit code $LASTEXITCODE." }
        if (-not (Test-Path -LiteralPath $RcVpnWireGuard)) { throw 'WireGuard installation did not provide wireguard.exe.' }
    }
    if ("$((Get-Service -Name WireGuardManager -ErrorAction SilentlyContinue).Status)" -ne 'Running') {
        Invoke-RcVpnWireGuard '/installmanagerservice'
    }
}

function Set-RcVpnFirewall {
    $off = @(Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { "$($_.Enabled)" -ne 'True' })
    if ($off.Count) { throw "Turn on Windows Firewall for these profiles first: $($off.Name -join ', ')." }
    foreach ($name in 'Rc-VPN-SSH', 'Rc-SSH-Untrusted') {
        Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    }
    $null = New-NetFirewallRule -Name 'Rc-SSH-Untrusted' -DisplayName 'rc: block SSH on Public and Domain networks' `
        -Direction Inbound -Action Block -Protocol TCP -LocalPort 22 -Profile Public, Domain
    $null = New-NetFirewallRule -Name 'Rc-VPN-SSH' -DisplayName 'rc: allow SSH on Private networks' `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 -Profile Private -RemoteAddress LocalSubnet -Program $RcVpnSshd
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
}

function Set-RcVpnSshConfig {
    $content = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sshd_config'))
    $path = Join-Path $env:ProgramData 'ssh\sshd_config'
    if (Test-Path -LiteralPath $path) {
        if ([IO.File]::ReadAllText($path) -ceq $content) { return $false }
        Move-Item -LiteralPath $path -Destination "$path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }
    [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
    $true
}

function Install-RcVpnSsh {
    $capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
    if ("$($capability.State)" -ne 'Installed') {
        $result = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
        if ($result.RestartNeeded) { throw 'Windows needs a restart to finish installing OpenSSH. Restart, then run this again.' }
    }
    Set-RcVpnFirewall
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd
    if (Set-RcVpnSshConfig) { Restart-Service -Name sshd }
}

function Write-RcVpnStatus {
    $address = Get-RcVpnAddress
    if ($address) {
        $category = (Get-NetConnectionProfile -InterfaceAlias $RcVpnTunnel -ErrorAction SilentlyContinue).NetworkCategory
        Write-Output "VPN: rc-vpn is on at $address ($category network). Turn it on or off from the WireGuard tray icon."
        $routes = @(Get-NetRoute -InterfaceAlias $RcVpnTunnel -AddressFamily IPv4 |
            Where-Object { $_.DestinationPrefix -notmatch '/32$|^224\.' } | ForEach-Object DestinationPrefix | Sort-Object -Unique)
        Write-Output "VPN routes: $($routes -join ', ')"
        if ($routes -notcontains $RcVpnHomeNetwork -and -not ($routes -match '/[01]$')) {
            Write-Output "The home network $RcVpnHomeNetwork is not routed through the VPN. Re-enroll with vpn/windows-connect.ps1 to add it."
        }
    } elseif (Test-Path -LiteralPath $RcVpnStoredConfig) {
        Write-Output 'VPN: rc-vpn is off. Turn it on from the WireGuard tray icon.'
    } else {
        Write-Output 'VPN: not enrolled yet. Run vpn/windows-connect.ps1.'
    }
    Write-Output "SSH: $((Get-Service -Name sshd).Status), key login only, on Private networks and the VPN. Blocked on Public networks."
}

function Install-RcVpn {
    Install-RcVpnWireGuard
    if (Test-RcVpnTunnelUp) { Set-RcVpnPrivate }
    Install-RcVpnSsh
    Write-RcVpnStatus
}

if ($MyInvocation.InvocationName -ne '.') {
    if (Test-RcVpnAdministrator) { Install-RcVpn } else { Start-RcVpnElevated $PSCommandPath }
}
