[CmdletBinding()]
param([switch]$ConfigOnly)

$ErrorActionPreference = 'Stop'
$script:RcRepoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'path.ps1')

function Invoke-RcCommand {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

function Install-RcPackage {
    param([string]$Id, [string]$Command)
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
    Invoke-RcCommand winget.exe @(
        'install', '--id', $Id, '--exact', '--source', 'winget', '--silent'
        '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'
    )
    Update-RcPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Id was installed, but $Command is unavailable. Open a new terminal and rerun this script."
    }
}

function Install-RcProgram {
    param([string]$Command, [string]$Url)
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return }
    $installer = Join-Path ([IO.Path]::GetTempPath()) ("rc-$([guid]::NewGuid().ToString('N')).ps1")
    try {
        Invoke-WebRequest -Uri $Url -OutFile $installer
        Invoke-RcCommand pwsh.exe @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer)
    } finally {
        if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer }
    }
    Update-RcPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Command is unavailable after installation. Open a new terminal and rerun this script."
    }
}

function Write-RcFile {
    param([string]$Path, [string]$Content)
    if (Test-Path -LiteralPath $Path) {
        if ([IO.File]::ReadAllText($Path) -ceq $Content) { return }
        Move-Item -LiteralPath $Path -Destination "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
    }
    $null = [IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Copy-RcFile {
    param([string]$Source, [string]$Destination)
    Write-RcFile -Path $Destination -Content ([IO.File]::ReadAllText($Source))
}

function Install-RcHerdrConfig {
    param([string]$Source, [string]$Destination)

    # The standalone Windows release does not support theme.custom.selection_fg.
    # Keep the shared source intact for the Linux/macOS build.
    $section = ''
    $content = foreach ($line in ([IO.File]::ReadAllText($Source) -split '(?<=\n)')) {
        if ($line -match '^\s*\[([^\]]+)\]') { $section = $Matches[1] }
        if ($section -eq 'theme.custom' -and $line -match '^\s*selection_fg\s*=') { continue }
        $line
    }
    Write-RcFile -Path $Destination -Content ($content -join '')
}

function Merge-RcSettings {
    param([System.Collections.IDictionary]$Destination, [System.Collections.IDictionary]$Source)
    foreach ($key in $Source.Keys) {
        if ($Destination[$key] -is [System.Collections.IDictionary] -and
            $Source[$key] -is [System.Collections.IDictionary]) {
            Merge-RcSettings $Destination[$key] $Source[$key]
        } else {
            $Destination[$key] = $Source[$key]
        }
    }
}

function Get-RcBash {
    $gitRoot = Split-Path (Split-Path (Get-Command git.exe -ErrorAction Stop).Source -Parent) -Parent
    $bashPath = Join-Path $gitRoot 'bin\bash.exe'
    if (-not (Test-Path -LiteralPath $bashPath)) {
        throw 'Git for Windows is required to apply the shared Codex settings.'
    }
    $bashPath
}

function Install-RcConfigs {
    param(
        [string]$UserDirectory,
        [string]$AppDataDirectory,
        [string]$ProfilePath,
        [string]$BashPath,
        [string]$CodexDirectory = (Join-Path $UserDirectory '.codex'),
        [string]$ClaudeDirectory = (Join-Path $UserDirectory '.claude'),
        [string]$HerdrConfigPath = (Join-Path $AppDataDirectory 'herdr\config.toml')
    )

    $configs = [ordered]@{
        'mise\config.toml' = Join-Path $UserDirectory '.config\mise\config.toml'
        'vim\vimrc' = Join-Path $UserDirectory '_vimrc'
        'vim\ideavimrc' = Join-Path $UserDirectory '.ideavimrc'
        'yazi\yazi.toml' = Join-Path $AppDataDirectory 'yazi\config\yazi.toml'
        'claude\CLAUDE.md' = Join-Path $ClaudeDirectory 'CLAUDE.md'
        'alacritty\alacritty.toml' = Join-Path $AppDataDirectory 'alacritty\alacritty.toml'
        'alacritty\MonokaiCustom.toml' = Join-Path $AppDataDirectory 'alacritty\themes\MonokaiCustom.toml'
        'alacritty\MonokaiCustomLight.toml' = Join-Path $AppDataDirectory 'alacritty\themes\MonokaiCustomLight.toml'
    }
    foreach ($config in $configs.GetEnumerator()) {
        Copy-RcFile (Join-Path $script:RcRepoRoot $config.Key) $config.Value
    }
    Install-RcHerdrConfig (Join-Path $script:RcRepoRoot 'herdr\config.toml') $HerdrConfigPath

    # The shared config imports this file. Keep an existing theme choice.
    $alacrittyTheme = Join-Path $AppDataDirectory 'alacritty\current-theme.toml'
    if (-not (Test-Path -LiteralPath $alacrittyTheme)) {
        Copy-RcFile (Join-Path $script:RcRepoRoot 'alacritty\MonokaiCustomLight.toml') $alacrittyTheme
    }

    $profileSource = (Join-Path $script:RcRepoRoot 'windows\profile.ps1').Replace("'", "''")
    $sourceLine = ". '$profileSource'"
    $profileContent = if (Test-Path -LiteralPath $ProfilePath) { [IO.File]::ReadAllText($ProfilePath) } else { '' }
    if ($sourceLine -notin @($profileContent -split '\r?\n')) {
        Write-RcFile $ProfilePath ($profileContent.TrimEnd("`r", "`n") + "`n$sourceLine`n")
    }

    $claudePath = Join-Path $ClaudeDirectory 'settings.json'
    $claudeSettings = if (Test-Path -LiteralPath $claudePath) {
        Get-Content -LiteralPath $claudePath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    } else { @{} }
    $managedSettings = Get-Content -LiteralPath (Join-Path $script:RcRepoRoot 'claude\settings.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json -AsHashtable
    Merge-RcSettings $claudeSettings $managedSettings
    Write-RcFile $claudePath (($claudeSettings | ConvertTo-Json -Depth 100) + "`n")
    foreach ($theme in Get-ChildItem -LiteralPath (Join-Path $script:RcRepoRoot 'claude\themes') -Filter *.json) {
        Copy-RcFile $theme.FullName (Join-Path $ClaudeDirectory "themes\$($theme.Name)")
    }

    $codexPath = Join-Path $CodexDirectory 'config.toml'
    $temporaryConfig = Join-Path ([IO.Path]::GetTempPath()) ("rc-codex-$([guid]::NewGuid().ToString('N')).toml")
    try {
        if (Test-Path -LiteralPath $codexPath) { Copy-Item -LiteralPath $codexPath -Destination $temporaryConfig }
        Invoke-RcCommand $BashPath @(
            '--noprofile', '--norc', (Join-Path $script:RcRepoRoot 'codex\install_codex.sh').Replace('\', '/')
            '--config-only', $temporaryConfig.Replace('\', '/')
        )
        Copy-RcFile $temporaryConfig $codexPath
    } finally {
        if (Test-Path -LiteralPath $temporaryConfig) { Remove-Item -LiteralPath $temporaryConfig }
    }
}

function Set-RcTerminalTheme {
    & (Join-Path $PSScriptRoot 'theme.ps1')
}

function Install-Rc {
    param(
        [string]$UserDirectory = $env:USERPROFILE,
        [string]$AppDataDirectory = $env:APPDATA,
        [string]$ProfilePath = $PROFILE.CurrentUserAllHosts
    )
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'This installer requires Windows.' }
    Update-RcPath
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        if (-not $ConfigOnly) { Install-RcPackage Microsoft.PowerShell pwsh.exe }
        Invoke-RcCommand pwsh.exe (@('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) +
            $(if ($ConfigOnly) { @('-ConfigOnly') } else { @() }))
        return
    }

    if (-not $ConfigOnly) {
        $packages = [ordered]@{
            'Microsoft.WindowsTerminal' = 'wt.exe'
            'Git.Git' = 'git.exe'
            'jdx.mise' = 'mise.exe'
            'vim.vim' = 'vim.exe'
            'sxyazi.yazi' = 'yazi.exe'
            'Amazon.AWSCLI' = 'aws.exe'
            'LLVM.LLVM' = 'clangd.exe'
        }
        foreach ($package in $packages.GetEnumerator()) { Install-RcPackage $package.Key $package.Value }
    }

    $configArguments = @{
        UserDirectory = $UserDirectory
        AppDataDirectory = $AppDataDirectory
        ProfilePath = $ProfilePath
        BashPath = Get-RcBash
    }
    if ($env:CODEX_HOME) { $configArguments.CodexDirectory = $env:CODEX_HOME }
    if ($env:CLAUDE_CONFIG_DIR) { $configArguments.ClaudeDirectory = $env:CLAUDE_CONFIG_DIR }
    if ($env:HERDR_CONFIG_PATH) { $configArguments.HerdrConfigPath = $env:HERDR_CONFIG_PATH }
    Install-RcConfigs @configArguments

    if (-not $ConfigOnly) {
        $miseConfig = Join-Path $UserDirectory '.config\mise\config.toml'
        Invoke-RcCommand mise.exe @('trust', $miseConfig)
        Invoke-RcCommand mise.exe @('install', '--jobs', '1')
        (& mise.exe env -s pwsh) -join "`n" | Invoke-Expression
        if ($LASTEXITCODE -ne 0) { throw 'mise environment activation failed.' }

        $plugPath = Join-Path $UserDirectory 'vimfiles\autoload\plug.vim'
        if (-not (Test-Path -LiteralPath $plugPath)) {
            $null = [IO.Directory]::CreateDirectory((Split-Path $plugPath -Parent))
            Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim' -OutFile $plugPath
        }
        Install-RcProgram codex.exe 'https://chatgpt.com/codex/install.ps1'
        Install-RcProgram claude.exe 'https://claude.ai/install.ps1'
        Install-RcProgram herdr.exe 'https://herdr.dev/install.ps1'
    }

    Set-RcTerminalTheme
    Write-Output 'Windows setup complete. Open PowerShell 7; run :PlugInstall in Vim to install plugins.'
}

if ($MyInvocation.InvocationName -ne '.') { Install-Rc }
