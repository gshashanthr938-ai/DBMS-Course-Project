$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = Get-Content -LiteralPath (Join-Path $projectDir '.local\config.json') | ConvertFrom-Json
$admin = Get-Content -LiteralPath (Join-Path $projectDir '.local\admin.json') | ConvertFrom-Json
$backupDir = Join-Path $projectDir '.local\backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path $backupDir "college-management-$stamp.sql"
$dump = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe'
$defaults = Join-Path ([System.IO.Path]::GetTempPath()) ("campus-ledger-" + [System.IO.Path]::GetRandomFileName() + '.cnf')
try {
    @("[client]","user=root","password=$($admin.password)","host=$($admin.host)","port=$($admin.port)") | Set-Content -LiteralPath $defaults -Encoding ascii
    & $dump "--defaults-extra-file=$defaults" --single-transaction --routines --triggers $config.database --result-file=$output
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
        throw 'Backup failed.'
    }
} finally {
    Remove-Item -LiteralPath $defaults -Force -ErrorAction SilentlyContinue
}
Write-Host "Backup created: $output"
