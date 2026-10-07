param(
    [string]$Query
)

$ErrorActionPreference = 'Stop'
$presentationDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appDir = Join-Path $presentationDir 'UI-Source'
$configPath = Join-Path $appDir '.local\config.json'
$mysqlExe = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe'
$defaultsPath = Join-Path $appDir '.local\presentation-client.cnf'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'The database is not configured. Run UI-Source\start.ps1 first.'
}
if (-not (Test-Path -LiteralPath $mysqlExe)) {
    throw 'The MySQL command-line client was not found.'
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
@(
    '[client]'
    "host=$($config.host)"
    "port=$($config.port)"
    "user=$($config.user)"
    "password=$($config.password)"
    'default-character-set=utf8mb4'
) | Set-Content -LiteralPath $defaultsPath -Encoding ascii

try {
    if ($Query) {
        & $mysqlExe "--defaults-extra-file=$defaultsPath" --table $config.database -e $Query
    } else {
        Write-Host ''
        Write-Host 'Campus Ledger presentation database' -ForegroundColor Green
        Write-Host "Database: $($config.database)  Server: $($config.host):$($config.port)"
        Write-Host 'Useful commands:' -ForegroundColor Cyan
        Write-Host '  SHOW TABLES;'
        Write-Host '  SELECT * FROM department ORDER BY department_id DESC;'
        Write-Host '  SELECT * FROM student ORDER BY student_id DESC LIMIT 10;'
        Write-Host '  SOURCE ../Live_Demo_Queries.sql;'
        Write-Host '  exit'
        Write-Host ''
        & $mysqlExe "--defaults-extra-file=$defaultsPath" --table $config.database
    }
} finally {
    Remove-Item -LiteralPath $defaultsPath -Force -ErrorAction SilentlyContinue
}
