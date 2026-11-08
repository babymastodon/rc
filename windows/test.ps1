#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'setup.ps1')

function Assert-Rc {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("rc-windows-tests-$([guid]::NewGuid().ToString('N'))")
$null = [IO.Directory]::CreateDirectory($testRoot)
$originalLocation = Get-Location
try {
    $userDirectory = Join-Path $testRoot "User's home [test]"
    $appDataDirectory = Join-Path $userDirectory 'App Data'
    $profilePath = Join-Path $userDirectory 'Documents\PowerShell\profile.ps1'
    $claudePath = Join-Path $userDirectory '.claude\settings.json'
    $codexPath = Join-Path $userDirectory '.codex\config.toml'
    $flatVimRoot = Join-Path $testRoot 'Programs\Vim'
    $versionedVimRoot = Join-Path $testRoot 'Program Files\Vim'
    $versionedVimDirectory = Join-Path $versionedVimRoot 'vim92'
    Write-RcFile (Join-Path $flatVimRoot 'vim.exe') ''
    Write-RcFile (Join-Path $versionedVimDirectory 'vim.exe') ''
    $originalPath = $env:PATH
    try {
        Update-RcPath -VimRoots @($flatVimRoot, $versionedVimRoot)
        Assert-Rc ($flatVimRoot -in ($env:PATH -split ';')) 'The per-user flat Vim installation was missed.'
        Assert-Rc ($versionedVimDirectory -in ($env:PATH -split ';')) 'The versioned Vim installation was missed.'
    } finally { $env:PATH = $originalPath }
    Write-RcFile $profilePath "function existing { 'preserved' }`n"
    Write-RcFile $claudePath '{"env":{"KEEP":"yes"},"permissions":{"allow":["Bash(git *)"]}}'
    $herdrPath = Join-Path $appDataDirectory 'herdr\config.toml'
    Write-RcFile $herdrPath 'onboarding = true'
    $alacrittyTheme = Join-Path $appDataDirectory 'alacritty\current-theme.toml'
    Write-RcFile $alacrittyTheme '# Keep my selected theme'
    Write-RcFile $codexPath @'
model = "keep-me"
model_reasoning_effort = "low"
[agents]
max_threads = 2
[profiles.work]
model = "also-keep-me"
'@
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    $gitPath = if ($git) { $git.Source } else { Join-Path $env:ProgramFiles 'Git\cmd\git.exe' }
    $bashPath = Join-Path (Split-Path (Split-Path $gitPath -Parent) -Parent) 'bin\bash.exe'
    Assert-Rc (Test-Path -LiteralPath $bashPath) 'Git for Windows is required to run these checks.'
    $guardPath = Join-Path $testRoot 'check-platform.sh'
    Write-RcFile $guardPath @'
uname() { printf '%s\n' MINGW64_NT-test; }
mkdir() { exit 97; }
ln() { exit 97; }
rm() { exit 97; }
source "$1"
'@
    $guardOutput = & $bashPath --noprofile --norc $guardPath.Replace('\', '/') (Join-Path $script:RcRepoRoot 'install.sh').Replace('\', '/') 2>&1
    Assert-Rc ($LASTEXITCODE -eq 1 -and "$guardOutput" -match 'windows/install.cmd') 'The Unix installer did not reject Windows before changing files.'
    $configArguments = @{
        UserDirectory = $userDirectory
        AppDataDirectory = $appDataDirectory
        ProfilePath = $profilePath
        BashPath = $bashPath
    }
    Install-RcConfigs @configArguments

    $claude = Get-Content -LiteralPath $claudePath -Raw | ConvertFrom-Json
    Assert-Rc ($claude.env.KEEP -eq 'yes') 'Claude custom settings were lost.'
    Assert-Rc ($claude.permissions.allow[0] -eq 'Bash(git *)') 'Claude nested settings were lost.'
    Assert-Rc ($claude.permissions.defaultMode -eq 'auto') 'Claude managed settings were not merged.'
    $codex = [IO.File]::ReadAllText($codexPath)
    Assert-Rc ($codex -match 'model = "keep-me"' -and $codex -match 'model = "also-keep-me"') 'Codex user settings were lost.'
    Assert-Rc ($codex -match 'model_reasoning_effort = "medium"' -and $codex -match 'max_threads = 10') 'Codex managed settings were not applied.'
    Assert-Rc ([IO.File]::ReadAllText($profilePath).StartsWith('function existing')) 'Existing PowerShell profile was overwritten.'
    Assert-Rc (Test-Path -LiteralPath (Join-Path $userDirectory '_vimrc')) 'Windows Vim configuration is missing.'
    Assert-Rc (Test-Path -LiteralPath (Join-Path $appDataDirectory 'yazi\config\yazi.toml')) 'Windows Yazi configuration is missing.'
    Assert-Rc (Test-Path -LiteralPath (Join-Path $appDataDirectory 'herdr\config.toml')) 'Windows Herdr configuration is missing.'
    $sharedHerdr = [IO.File]::ReadAllText((Join-Path $script:RcRepoRoot 'herdr\config.toml'))
    $windowsHerdr = [IO.File]::ReadAllText($herdrPath)
    $expectedHerdr = $sharedHerdr -replace '(?m)^selection_fg\s*=[^\r\n]*(?:\r?\n|$)', ''
    Assert-Rc ($windowsHerdr -ceq $expectedHerdr) 'Windows Herdr settings do not match the supported repo options.'
    Assert-Rc ($sharedHerdr -match '(?m)^selection_fg\s*=') 'The shared Linux/macOS Herdr option was removed.'
    Assert-Rc (@(Get-ChildItem -LiteralPath (Split-Path $herdrPath -Parent) -Filter 'config.toml.backup-*').Count -eq 1) 'Existing Herdr config was not backed up.'
    Assert-Rc ([IO.File]::ReadAllText($alacrittyTheme) -eq '# Keep my selected theme') 'The Alacritty theme choice was overwritten.'
    foreach ($file in 'alacritty.toml', 'themes\MonokaiCustom.toml', 'themes\MonokaiCustomLight.toml') {
        Assert-Rc (Test-Path -LiteralPath (Join-Path $appDataDirectory "alacritty\$file")) "Alacritty config missing: $file"
    }
    Assert-Rc (Test-Path -LiteralPath (Join-Path $userDirectory '.claude\themes\terminal-ansi.json')) 'Claude theme is missing.'
    Assert-Rc (Test-Path -LiteralPath (Join-Path $userDirectory '.claude\CLAUDE.md')) 'Claude instructions are missing.'

    $backupsBefore = @(Get-ChildItem -LiteralPath $userDirectory -Recurse -Filter '*.backup-*').Count
    Install-RcConfigs @configArguments
    Assert-Rc (@(Get-ChildItem -LiteralPath $userDirectory -Recurse -Filter '*.backup-*').Count -eq $backupsBefore) 'A repeated config install rewrote files.'
    $sourceLines = @([IO.File]::ReadAllLines($profilePath) | Where-Object { $_ -like '. *profile.ps1*' })
    Assert-Rc ($sourceLines.Count -eq 1) 'PowerShell profile was sourced more than once.'

    $customArguments = $configArguments.Clone()
    $customArguments.ClaudeDirectory = Join-Path $userDirectory 'custom Claude'
    $customArguments.CodexDirectory = Join-Path $userDirectory 'custom Codex'
    $customArguments.HerdrConfigPath = Join-Path $userDirectory 'custom Herdr\settings.toml'
    Remove-Item -LiteralPath $alacrittyTheme
    Install-RcConfigs @customArguments
    Assert-Rc (Test-Path -LiteralPath (Join-Path $customArguments.ClaudeDirectory 'settings.json')) 'Custom Claude destination was ignored.'
    Assert-Rc (Test-Path -LiteralPath (Join-Path $customArguments.ClaudeDirectory 'CLAUDE.md')) 'Custom Claude instructions are missing.'
    Assert-Rc (Test-Path -LiteralPath (Join-Path $customArguments.CodexDirectory 'config.toml')) 'Custom Codex destination was ignored.'
    Assert-Rc (Test-Path -LiteralPath $customArguments.HerdrConfigPath) 'Custom Herdr destination was ignored.'
    Assert-Rc ([IO.File]::ReadAllText($alacrittyTheme) -ceq [IO.File]::ReadAllText((Join-Path $script:RcRepoRoot 'alacritty\MonokaiCustomLight.toml'))) 'Fresh Alacritty theme import was not initialized.'

    $terminalPath = Join-Path $testRoot 'settings.json'
    Write-RcFile $terminalPath @'
{
    // A valid Windows Terminal settings file can contain comments and trailing commas.
    "copyOnSelect": true,
    "profiles": {
        "defaults": {},
        "list": [
            {"guid":"{61c54bbd-c2c6-5271-96e7-009a87ff44bf}","name":"Windows PowerShell","background":"#123456","font":{"face":"Cascadia Mono","size":14}},
            {"name":"Command Prompt","commandline":"cmd.exe","colorScheme":"Existing"},
        ]
    },
    "schemes": [{"name":"Existing","background":"#123456"}],
}
'@
    & (Join-Path $PSScriptRoot 'theme.ps1') -SettingsPath $terminalPath
    $terminal = Get-Content -LiteralPath $terminalPath -Raw | ConvertFrom-Json
    $powerShell = $terminal.profiles.list | Where-Object { $_.name -eq 'Windows PowerShell' }
    Assert-Rc ($terminal.copyOnSelect -eq $true) 'Unrelated Terminal settings changed.'
    Assert-Rc ($terminal.theme -eq 'system') 'Terminal does not follow Windows light/dark mode.'
    Assert-Rc ($terminal.profiles.defaults.colorScheme.light -eq 'Monokai Custom Light' -and $terminal.profiles.defaults.colorScheme.dark -eq 'Monokai Custom') 'New profiles do not inherit the shared palettes.'
    Assert-Rc ($null -eq $powerShell.background) 'A PowerShell background override still masks the shared theme.'
    Assert-Rc ($powerShell.font.face -eq 'Cascadia Mono' -and $null -eq $powerShell.font.size) 'Font defaults or family were changed incorrectly.'
    Assert-Rc ($powerShell.colorScheme.dark -eq 'Monokai Custom' -and $powerShell.colorScheme.light -eq 'Monokai Custom Light') 'PowerShell palettes are incorrect.'
    Assert-Rc (($terminal.profiles.list | Where-Object { $_.name -eq 'Command Prompt' }).colorScheme -eq 'Existing') 'A different shell profile changed.'
    Assert-Rc (($terminal.schemes | Where-Object { $_.name -eq 'Monokai Custom' }).blue -eq '#fc9867') 'Ghostty ANSI palette mapping is incorrect.'
    Assert-Rc (($terminal.schemes | Where-Object { $_.name -eq 'Monokai Custom Light' }).background -eq '#faf4f2') 'Ghostty light palette is incorrect.'
    $terminalBefore = [IO.File]::ReadAllText($terminalPath)
    & (Join-Path $PSScriptRoot 'theme.ps1') -SettingsPath $terminalPath
    Assert-Rc ([IO.File]::ReadAllText($terminalPath) -ceq $terminalBefore) 'Repeated theme installation changed settings.'

    $freshTerminalPath = Join-Path $testRoot 'Fresh Terminal\settings.json'
    & (Join-Path $PSScriptRoot 'theme.ps1') -SettingsPath $freshTerminalPath
    $freshTerminal = Get-Content -LiteralPath $freshTerminalPath -Raw | ConvertFrom-Json
    Assert-Rc ($freshTerminal.profiles.list.Count -eq 2) 'Fresh Terminal profiles were not initialized.'

    function mise.exe { '$env:RC_TEST_MISE_ACTIVATED = "yes"' }
    function herdr { $script:herdrArguments = @($args) }
    function git { $script:gitArguments = @($args); $global:LASTEXITCODE = 0 }
    function yazi {
        $cwdIndex = [array]::IndexOf($args, '--cwd-file')
        $script:lastCwdFile = $args[$cwdIndex + 1]
        [IO.File]::WriteAllText($script:lastCwdFile, $script:nextDirectory + "`n")
    }
    . (Join-Path $PSScriptRoot 'profile.ps1')
    Assert-Rc ($env:RC_TEST_MISE_ACTIVATED -eq 'yes') 'PowerShell mise activation failed.'
    Assert-Rc ([bool](Get-Command md -CommandType Alias)) 'The built-in md alias was replaced.'
    hoo 'work box'
    Assert-Rc ($herdrArguments.Count -eq 2 -and $herdrArguments[0] -eq '--remote' -and $herdrArguments[1] -eq 'work box') 'hoo did not preserve its remote argument.'
    hoo --version
    Assert-Rc ($herdrArguments.Count -eq 1 -and $herdrArguments[0] -eq '--version') 'hoo misrouted a flag as a remote host.'
    ga 'file with spaces.txt'
    Assert-Rc ($gitArguments.Count -eq 3 -and $gitArguments[2] -eq 'file with spaces.txt') 'Git shortcut split a filename.'
    $script:nextDirectory = $userDirectory
    y
    Assert-Rc ((Get-Location).Path -eq $userDirectory) 'Yazi did not change to a path containing spaces and brackets.'
    Assert-Rc (-not (Test-Path -LiteralPath $lastCwdFile)) 'Yazi left its temporary cwd file behind.'
    src
    Assert-Rc ($env:RC_TEST_MISE_ACTIVATED -eq 'yes') 'PowerShell profile reload failed.'

    $failureDetected = $false
    try { Invoke-RcCommand cmd.exe @('/d', '/c', 'exit 7') } catch { $failureDetected = $true }
    Assert-Rc $failureDetected 'A failed native command was ignored.'

    $script:bootstrapPackages = @()
    $script:bootstrapPrograms = @()
    $script:bootstrapCommands = @()
    function Install-RcPackage { param($Id, $Command); $script:bootstrapPackages += $Id }
    function Install-RcProgram { param($Command, $Url); $script:bootstrapPrograms += $Command }
    function Invoke-RcCommand {
        param($Command, $Arguments)
        $script:bootstrapCommands += "$Command $($Arguments -join ' ')"
        $global:LASTEXITCODE = 0
    }
    function Install-RcConfigs { $script:bootstrapConfigsInstalled = $true }
    function Install-RcUserPath { $script:bootstrapPathInstalled = $true }
    function Set-RcTerminalTheme { $script:bootstrapThemeInstalled = $true }
    function Invoke-WebRequest { param($Uri, $OutFile); $script:bootstrapDownloads += $Uri }
    $script:ConfigOnly = $false
    Install-Rc -UserDirectory $userDirectory -AppDataDirectory $appDataDirectory -ProfilePath $profilePath
    Assert-Rc ($bootstrapPackages.Count -eq 7 -and 'sxyazi.yazi' -in $bootstrapPackages -and 'Amazon.AWSCLI' -in $bootstrapPackages) 'The bootstrap did not select the expected Windows packages.'
    Assert-Rc ($bootstrapPrograms.Count -eq 3 -and 'codex.exe' -in $bootstrapPrograms -and 'herdr.exe' -in $bootstrapPrograms) 'The bootstrap did not select the expected native programs.'
    Assert-Rc ($bootstrapConfigsInstalled -and $bootstrapThemeInstalled) 'The bootstrap omitted configuration or Terminal setup.'
    Assert-Rc $bootstrapPathInstalled 'The bootstrap did not persist tool paths for future shells.'
    Assert-Rc ('mise.exe install --jobs 1' -in $bootstrapCommands) 'Shared mise tools were not requested.'
    $script:ConfigOnly = $true
    $script:bootstrapPackages = @()
    $script:bootstrapPrograms = @()
    $script:bootstrapCommands = @()
    Install-Rc -UserDirectory $userDirectory -AppDataDirectory $appDataDirectory -ProfilePath $profilePath
    Assert-Rc ($bootstrapPackages.Count -eq 0 -and $bootstrapPrograms.Count -eq 0 -and $bootstrapCommands.Count -eq 0) 'Config-only mode attempted package installation.'
    Write-Output 'Windows checks passed: config merges, backups, repeat installs, JSONC, fresh Terminal setup, shell shortcuts, and bootstrap orchestration.'
} finally {
    Set-Location -LiteralPath $originalLocation.Path
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolvedTestRoot.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolvedTestRoot) -notlike 'rc-windows-tests-*') {
        throw 'Refusing to remove a test directory outside the expected temporary location.'
    }
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
}
