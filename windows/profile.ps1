. (Join-Path $PSScriptRoot 'path.ps1')
Update-RcPath

if (Get-Command mise.exe -ErrorAction SilentlyContinue) {
    (& mise.exe activate pwsh) -join "`n" | Invoke-Expression
}
$env:EDITOR = 'vim'
$env:VISUAL = 'vim'

if (-not $env:YAZI_FILE_ONE -and (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    $rcGitRoot = Split-Path (Split-Path (Get-Command git.exe).Source -Parent) -Parent
    $rcFileOne = Join-Path $rcGitRoot 'usr\bin\file.exe'
    if (Test-Path -LiteralPath $rcFileOne) { $env:YAZI_FILE_ONE = $rcFileOne }
}

Set-Alias g git
Set-Alias lg lazygit
function ga { git add . @args }
function st { git status @args; if ($LASTEXITCODE -eq 0) { git diff --stat } }
function gs { git -c color.status=always status -s; git diff --stat; git diff --cached --stat }
function pl { git pull @args }
function ph { git push --force-with-lease @args }
function br { git log --graph --oneline --decorate --all @args }
function vimdiff { vim -d @args }
function src { . (Join-Path $PSScriptRoot 'profile.ps1') }

function Get-RcGitBase {
    $base = git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
    if ($LASTEXITCODE -eq 0) { return $base }
    foreach ($base in 'origin/HEAD', 'origin/main', 'origin/master', 'main', 'master') {
        git rev-parse --verify --quiet "$base^{commit}" 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) { return $base }
    }
}

function gd {
    if ($args.Count) { git diff @args; return }
    $base = Get-RcGitBase
    if ($base) { git diff $base } else { git diff }
}

function mg {
    $base = Get-RcGitBase
    if (-not $base) { throw 'No upstream or default branch found to merge.' }
    if ($base -match '^([^/]+)/') {
        git fetch $Matches[1]
        if ($LASTEXITCODE -ne 0) { return }
    }
    git merge $base --no-edit @args
}

function hoo {
    if ($args.Count -eq 1 -and -not $args[0].StartsWith('-')) { herdr --remote @args }
    else { herdr @args }
}

function y {
    $cwdFile = [IO.Path]::GetTempFileName()
    try {
        yazi @args --cwd-file $cwdFile
        $newDirectory = [IO.File]::ReadAllText($cwdFile).TrimEnd([char[]]"`r`n`0")
        if ($newDirectory -and (Test-Path -LiteralPath $newDirectory -PathType Container)) {
            Set-Location -LiteralPath $newDirectory
        }
    } finally {
        Remove-Item -LiteralPath $cwdFile
    }
}
