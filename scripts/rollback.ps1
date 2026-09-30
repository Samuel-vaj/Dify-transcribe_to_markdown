# Revert Track A patches from a Dify checkout on Windows.
#   usage: powershell -ExecutionPolicy Bypass -File scripts\rollback.ps1 D:\dify
param([Parameter(Mandatory = $true)][string]$Target)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Push-Location $Target
try {
    Write-Output "==> reverse-applying patches"
    git apply -R "$here\patches\02-weaviate-delete-fix.patch"
    git apply -R "$here\patches\01-track-a.patch"

    Write-Output "==> done. remaining changes:"
    git status --porcelain=v1
}
finally {
    Pop-Location
}
