#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-install.ps1')

$RcVpnService = 'WireGuardTunnel$' + $RcVpnTunnel

function Read-RcVpnClipboard {
    while ($true) {
        $null = Read-Host 'Copy the config printed by add-client.sh, from [Interface] through PersistentKeepalive, then press Enter'
        try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
        $lines = [Collections.Generic.List[string]]::new()
        $peer = $false
        foreach ($line in ("$(Get-Clipboard -Raw)" -split '\r?\n')) {
            if (-not $lines.Count -and $line.Trim() -ne '[Interface]') { continue }
            if ($peer -and -not $line.Trim()) { break }
            if ($line.Trim() -eq '[Peer]') { $peer = $true }
            $lines.Add($line)
        }
        $text = ($lines -join "`n").Trim()
        if ($peer -and $text -match '(?m)^\s*PrivateKey\s*=') { return $text + "`n" }
        Write-Host 'The clipboard does not hold a WireGuard config. Copy it again.'
    }
}

function Add-RcVpnHomeRoute {
    param([string]$Config)
    $line = [regex]::Match($Config, '(?im)^([ \t]*AllowedIPs[ \t]*=[ \t]*)([^\r\n]*?)[ \t]*(?=\r?$)')
    if (-not $line.Success) { throw 'The config has no AllowedIPs line. Paste the whole config from add-client.sh.' }
    $routes = $line.Groups[2].Value -split '\s*,\s*'
    if ($routes -contains '0.0.0.0/0' -or $routes -contains $RcVpnHomeNetwork) { return $Config }
    Write-Host "Also routing the home network $RcVpnHomeNetwork through the VPN."
    $Config.Remove($line.Index, $line.Length).Insert($line.Index, "$($line.Value.TrimEnd()), $RcVpnHomeNetwork")
}

function Import-RcVpnConfig {
    param([string]$Content)
    Wait-RcVpn { Test-Path -LiteralPath $RcVpnStore } 'WireGuard has not created its configuration store.'
    $staging = Join-Path $RcVpnStore "$RcVpnTunnel.staging"
    $plain = Join-Path $RcVpnStore "$RcVpnTunnel.conf"
    try {
        [IO.File]::WriteAllText($staging, $Content, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($staging, $plain)
        Wait-RcVpn { (Test-Path -LiteralPath $RcVpnStoredConfig) -and -not (Test-Path -LiteralPath $plain) } `
            'WireGuard rejected the configuration. Check that the whole config was pasted, then try again.'
    } finally {
        foreach ($path in $staging, $plain) {
            if (Test-Path -LiteralPath $path) { [IO.File]::Delete($path) }
        }
    }
}

function Stop-RcVpnTunnel {
    if (-not (Get-Service -Name $RcVpnService -ErrorAction SilentlyContinue)) { return }
    Invoke-RcVpnWireGuard "/uninstalltunnelservice $RcVpnTunnel"
    Wait-RcVpn { -not (Get-Service -Name $RcVpnService -ErrorAction SilentlyContinue) } 'WireGuard did not stop the rc-vpn tunnel.'
}

function Start-RcVpnTunnel {
    Invoke-RcVpnWireGuard "/installtunnelservice `"$RcVpnStoredConfig`""
    Wait-RcVpn { Test-RcVpnTunnelUp } 'The rc-vpn tunnel did not come up.'
}

function Connect-RcVpn {
    if ("$((Get-Service -Name WireGuardManager -ErrorAction SilentlyContinue).Status)" -ne 'Running') {
        throw 'Run vpn/windows-install.ps1 first.'
    }
    $config = Add-RcVpnHomeRoute (Read-RcVpnClipboard)
    Stop-RcVpnTunnel
    if (Test-Path -LiteralPath $RcVpnStoredConfig) { [IO.File]::Delete($RcVpnStoredConfig) }
    Import-RcVpnConfig $config
    Set-Clipboard -Value $null
    Start-RcVpnTunnel
    Set-RcVpnPrivate
    Write-RcVpnStatus
}

if ($MyInvocation.InvocationName -ne '.') {
    if (Test-RcVpnAdministrator) { Connect-RcVpn } else { Start-RcVpnElevated $PSCommandPath }
}
