$ErrorActionPreference = 'Stop'
$presentationDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startApp = Join-Path $presentationDir 'UI-Source\start.ps1'
$openDatabase = Join-Path $presentationDir 'Open_Database_Console.ps1'

& powershell -ExecutionPolicy Bypass -File $startApp

Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoExit',
    '-ExecutionPolicy', 'Bypass',
    '-File', "`"$openDatabase`""
)

Write-Host 'Presentation mode is ready:' -ForegroundColor Green
Write-Host '  Website: http://127.0.0.1:5080'
Write-Host '  Database: opened in the second PowerShell window'
