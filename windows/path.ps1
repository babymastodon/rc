function Get-RcToolPaths {
    @(
        "$env:ProgramFiles\Git\cmd"
        "$env:LOCALAPPDATA\Programs\Git\cmd"
        "$env:ProgramFiles\LLVM\bin"
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
        "$env:USERPROFILE\.local\bin"
        "$env:USERPROFILE\.herdr\packages\standalone\current"
        "$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin"
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -Unique
}

function Install-RcUserPath {
    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $updatedPath = (@(
        $currentPath -split ';'
        Get-RcToolPaths
    ) | Where-Object { $_ } | Select-Object -Unique) -join ';'
    if ($currentPath -cne $updatedPath) {
        [Environment]::SetEnvironmentVariable('Path', $updatedPath, 'User')
    }
    Update-RcPath
}

function Update-RcPath {
    param([string[]]$VimRoots = @(
        "$env:LOCALAPPDATA\Programs\Vim"
        "$env:ProgramW6432\Vim"
        "$env:ProgramFiles\Vim"
        "${env:ProgramFiles(x86)}\Vim"
    ))
    $toolPaths = @(Get-RcToolPaths)
    foreach ($vimRoot in $VimRoots | Select-Object -Unique) {
        if (Test-Path -LiteralPath $vimRoot) {
            if (Test-Path -LiteralPath (Join-Path $vimRoot 'vim.exe') -PathType Leaf) {
                $toolPaths += $vimRoot
            }
            $toolPaths += Get-ChildItem -LiteralPath $vimRoot -Directory -Filter 'vim*' |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'vim.exe') -PathType Leaf } |
                Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName
        }
    }
    $env:PATH = (@(
        $env:PATH -split ';'
        [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
        [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
        $toolPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
    ) | Where-Object { $_ } | Select-Object -Unique) -join ';'
}
