param(
    [Parameter(Mandatory = $true)]
    [string] $Directory,
    [Parameter(Mandatory = $true)]
    [ValidateSet('64bit', 'arm64')]
    [string] $Architecture
)

$ErrorActionPreference = 'Stop'
Get-Command cargo, git | Out-Null
$source = Join-Path $Directory 'source'
$archive = Join-Path $Directory 'archive'
$extracted = Join-Path $Directory 'extracted'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($archive, $extracted)
Move-Item (Get-ChildItem $extracted -Directory).FullName $source
Remove-Item $extracted, $archive
$patch = Join-Path $PSScriptRoot 'runtime.patch'
git -C $source apply --ignore-space-change $patch

if ($LASTEXITCODE -ne 0) {
    throw 'Upstream runtime discovery changed; review the packaging patch.'
}

$target = if ($Architecture -eq 'arm64') {
    'aarch64-pc-windows-msvc'
} else {
    'x86_64-pc-windows-msvc'
}

$disabled = $env:MITOS_DISABLE_AUTO_GRAMMAR_BUILD
Push-Location $source

try {
    Remove-Item Env:MITOS_DISABLE_AUTO_GRAMMAR_BUILD -ErrorAction SilentlyContinue
    cargo build --profile opt --locked --target $target --target-dir target

    if ($LASTEXITCODE -ne 0) {
        throw 'Mitos source build failed.'
    }
} finally {
    $env:MITOS_DISABLE_AUTO_GRAMMAR_BUILD = $disabled
    Pop-Location
}

Copy-Item "$source/target/$target/opt/ms.exe" $Directory
Remove-Item "$source/runtime/grammars/sources" -Recurse -Force
Copy-Item "$source/runtime" $Directory -Recurse
Copy-Item "$source/LICENSE" $Directory
Remove-Item $source -Recurse -Force
