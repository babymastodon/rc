#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SettingsPath
)

$ErrorActionPreference = 'Stop'

if (-not $SettingsPath) {
    $settingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $existingPaths = @($settingsPaths | Where-Object { Test-Path -LiteralPath $_ })
    if ($existingPaths.Count -eq 0) { $existingPaths = @($settingsPaths[0]) }
    foreach ($path in $existingPaths) {
        & $PSCommandPath -SettingsPath $path
    }
    return
}
$SettingsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SettingsPath)

function ConvertFrom-GhosttyTheme {
    param([string]$Path, [string]$Name)

    $scheme = [ordered]@{ name = $Name }
    # Ghostty uses ANSI order; Windows Terminal calls magenta "purple".
    $paletteNames = @(
        'black', 'red', 'green', 'yellow', 'blue', 'purple', 'cyan', 'white'
        'brightBlack', 'brightRed', 'brightGreen', 'brightYellow'
        'brightBlue', 'brightPurple', 'brightCyan', 'brightWhite'
    )
    $propertyNames = @{
        'background' = 'background'
        'foreground' = 'foreground'
        'cursor-color' = 'cursorColor'
        'selection-background' = 'selectionBackground'
    }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*palette\s*=\s*(\d+)\s*=\s*(#[\da-fA-F]{6})\s*$') {
            $index = [int]$Matches[1]
            if ($index -lt $paletteNames.Count) {
                $scheme[$paletteNames[$index]] = $Matches[2]
            }
        } elseif ($line -match '^\s*([\w-]+)\s*=\s*(#[\da-fA-F]{6})\s*$') {
            if ($propertyNames.ContainsKey($Matches[1])) {
                $scheme[$propertyNames[$Matches[1]]] = $Matches[2]
            }
        }
    }
    foreach ($required in $paletteNames + @($propertyNames.Values)) {
        if (-not $scheme.Contains($required)) {
            throw "Missing '$required' in Ghostty theme: $Path"
        }
    }
    [pscustomobject]$scheme
}

$ghosttyDirectory = Join-Path $PSScriptRoot '..\ghostty'
$schemes = @(
    ConvertFrom-GhosttyTheme (Join-Path $ghosttyDirectory 'monokai-custom.theme') 'Monokai Custom'
    ConvertFrom-GhosttyTheme (Join-Path $ghosttyDirectory 'monokai-custom-light.theme') 'Monokai Custom Light'
)
$settings = if (Test-Path -LiteralPath $SettingsPath) {
    Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else { [pscustomobject]@{} }
if (-not $settings.profiles) {
    $settings | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not $settings.profiles.defaults) {
    $settings.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) -Force
}
# Match the shared terminals and let new profiles inherit the same palette.
$settings | Add-Member -NotePropertyName theme -NotePropertyValue 'system' -Force
$colorScheme = [pscustomobject]@{
    light = 'Monokai Custom Light'
    dark = 'Monokai Custom'
}
$settings.profiles.defaults | Add-Member -NotePropertyName colorScheme -NotePropertyValue $colorScheme -Force
$settings.profiles.defaults | Add-Member -NotePropertyName cursorShape -NotePropertyValue 'filledBox' -Force
$profileList = @($settings.profiles.list | Where-Object { $null -ne $_ })
foreach ($standardProfile in @(
    [pscustomobject]@{
        guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'
        name = 'Windows PowerShell'
        commandline = '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe'
    }
    [pscustomobject]@{
        guid = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'
        name = 'PowerShell'
        source = 'Windows.Terminal.PowershellCore'
    }
)) {
    if ($standardProfile.guid -notin $profileList.guid) { $profileList += $standardProfile }
}
$settings.profiles | Add-Member -NotePropertyName list -NotePropertyValue $profileList -Force
$powerShellProfiles = @($settings.profiles.list | Where-Object {
    $_.name -match 'PowerShell|^pwsh$' -or
    $_.source -eq 'Windows.Terminal.PowershellCore' -or
    $_.commandline -match '(?i)(?:^|[\\/"\s])(?:powershell|pwsh)(?:\.exe)?(?:["\s]|$)'
})
$settings | Add-Member -NotePropertyName schemes -NotePropertyValue @(
    @($settings.schemes | Where-Object { $_.name -notin $schemes.name }) + $schemes
) -Force
foreach ($terminalProfile in $powerShellProfiles) {
    # Direct color overrides take precedence over the shared color scheme.
    foreach ($property in 'foreground', 'background', 'cursorColor', 'selectionBackground') {
        $terminalProfile.PSObject.Properties.Remove($property)
    }
    # Inherit Windows Terminal's default font size.
    if ($terminalProfile.font) {
        $terminalProfile.font.PSObject.Properties.Remove('size')
        if (@($terminalProfile.font.PSObject.Properties).Count -eq 0) {
            $terminalProfile.PSObject.Properties.Remove('font')
        }
    }
    $terminalProfile | Add-Member -NotePropertyName colorScheme -NotePropertyValue $colorScheme -Force
    $terminalProfile | Add-Member -NotePropertyName cursorShape -NotePropertyValue 'filledBox' -Force
}

$json = ($settings | ConvertTo-Json -Depth 100) + [Environment]::NewLine
if (Test-Path -LiteralPath $SettingsPath) {
    if ([IO.File]::ReadAllText($SettingsPath) -ceq $json) { return }
    $backupPath = "$SettingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
    Copy-Item -LiteralPath $SettingsPath -Destination $backupPath
    Write-Output "Backup: $backupPath"
}
$null = [IO.Directory]::CreateDirectory((Split-Path $SettingsPath -Parent))
[System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output "Applied Ghostty's light/dark Monokai themes to: $($powerShellProfiles.name -join ', ')"
Write-Output "Settings: $SettingsPath"
