function Update-RcPath {
    param([string[]]$VimRoots = @(
        "$env:LOCALAPPDATA\Programs\Vim"
        "$env:ProgramW6432\Vim"
        "$env:ProgramFiles\Vim"
        "${env:ProgramFiles(x86)}\Vim"
    ))
    $toolPaths = @(
        "$env:ProgramFiles\Git\cmd"
        "$env:ProgramFiles\LLVM\bin"
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
        "$env:USERPROFILE\.local\bin"
    )
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
