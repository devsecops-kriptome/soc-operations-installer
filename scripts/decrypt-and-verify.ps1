param(
    [Parameter(Mandatory = $true)]
    [string]$Asset,

    [Parameter(Mandatory = $true)]
    [string]$Identity,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$checksumsPath = Join-Path $repositoryRoot 'SHA256SUMS'
$encryptedName = Split-Path -Leaf $Asset
$plainName = $encryptedName -replace '\.age$', ''
$plainPath = Join-Path $OutputDirectory $plainName

function Get-ExpectedHash([string]$Name) {
    $line = Get-Content -LiteralPath $checksumsPath |
        Where-Object { $_ -match "^[0-9a-f]{64}  $([regex]::Escape($Name))$" } |
        Select-Object -First 1
    if (-not $line) {
        throw "No checksum is registered for $Name"
    }
    return ($line -split '  ')[0]
}

function Assert-FileHash([string]$Path, [string]$Expected) {
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected) {
        throw "SHA-256 mismatch for $(Split-Path -Leaf $Path)"
    }
}

if (-not (Test-Path -LiteralPath $Asset -PathType Leaf)) {
    throw "Encrypted asset not found: $Asset"
}
if (-not (Test-Path -LiteralPath $Identity -PathType Leaf)) {
    throw "age identity not found: $Identity"
}
if (Test-Path -LiteralPath $plainPath) {
    throw "Refusing to overwrite: $plainPath"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Assert-FileHash $Asset (Get-ExpectedHash $encryptedName)

$ageCommand = Get-Command age -ErrorAction SilentlyContinue
if ($ageCommand) {
    $ageExecutable = $ageCommand.Source
} else {
    $wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    $ageExecutable = Get-ChildItem -LiteralPath $wingetPackages -Filter 'age.exe' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like '*FiloSottile.age*' } |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $ageExecutable) {
        throw 'age was not found. Install it with: winget install --id FiloSottile.age --exact'
    }
}

& $ageExecutable --decrypt --identity $Identity --output $plainPath $Asset
if ($LASTEXITCODE -ne 0) {
    throw 'age decryption failed'
}

Assert-FileHash $plainPath (Get-ExpectedHash $plainName)
tar -xzf $plainPath -C $OutputDirectory
if ($LASTEXITCODE -ne 0) {
    throw 'TAR extraction failed'
}

Write-Host "Verified and extracted release into $OutputDirectory"
