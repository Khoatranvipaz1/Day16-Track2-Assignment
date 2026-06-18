$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $repoRoot "vinuni_accessKeys.csv"

if (-not (Test-Path $csvPath)) {
    throw "Cannot find AWS access key CSV at: $csvPath"
}

$row = Import-Csv $csvPath | Select-Object -First 1

if (-not $row.'Access key ID' -or -not $row.'Secret access key') {
    throw "CSV must contain 'Access key ID' and 'Secret access key' columns."
}

$env:AWS_ACCESS_KEY_ID = $row.'Access key ID'
$env:AWS_SECRET_ACCESS_KEY = $row.'Secret access key'
$env:AWS_DEFAULT_REGION = "us-east-1"

Write-Host "AWS environment variables loaded for region us-east-1."
Write-Host "Access key loaded from vinuni_accessKeys.csv without printing the secret."
