# Apply Track A patches to a Dify 1.17.0 checkout on Windows.
#   usage: powershell -ExecutionPolicy Bypass -File scripts\apply.ps1 D:\dify
param([Parameter(Mandatory = $true)][string]$Target)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Test-Path (Join-Path $Target '.git'))) {
    throw "$Target is not a git checkout"
}

Push-Location $Target
try {
    Write-Output "==> checking patches against $Target"
    git apply --check "$here\patches\01-track-a.patch"
    git apply --check "$here\patches\02-weaviate-delete-fix.patch"

    Write-Output "==> applying"
    git apply "$here\patches\01-track-a.patch"
    git apply "$here\patches\02-weaviate-delete-fix.patch"

    Write-Output "==> done. changed files:"
    git status --porcelain=v1
}
finally {
    Pop-Location
}

Write-Output ""
Write-Output "Next: append env\transcribe.env.snippet to docker\.env, then"
Write-Output "      docker compose build api worker && docker compose up -d api worker"
