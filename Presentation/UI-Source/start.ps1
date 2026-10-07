$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = Join-Path $projectDir '.venv\Scripts\python.exe'
$mysqlExe = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe'
$dataDir = Join-Path $projectDir '.local\mysql-data'
$configFile = Join-Path $projectDir '.local\config.json'

if (-not (Test-Path -LiteralPath $mysqlExe)) { throw 'MySQL Server 8.0 was not found in the expected Program Files location.' }
if (-not (Test-Path -LiteralPath $pythonExe)) {
    $pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pythonLauncher) {
        & $pythonLauncher.Source -3 -m venv (Join-Path $projectDir '.venv')
    } else {
        $bundledPython = 'C:\Users\gshas\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
        if (Test-Path -LiteralPath $bundledPython) {
            & $bundledPython -m venv (Join-Path $projectDir '.venv')
        } else {
            $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonCommand) { throw 'Python 3 was not found. Install Python 3.12 or later and rerun start.ps1.' }
            & $pythonCommand.Source -m venv (Join-Path $projectDir '.venv')
        }
    }
    if (-not (Test-Path -LiteralPath $pythonExe)) { throw 'Python could not create the project virtual environment.' }
    & (Join-Path $projectDir '.venv\Scripts\python.exe') -m pip install -r (Join-Path $projectDir 'requirements.txt')
}
if (-not (Test-Path -LiteralPath $dataDir)) {
    New-Item -ItemType Directory -Force -Path (Join-Path $projectDir '.local') | Out-Null
    & $mysqlExe --no-defaults --initialize-insecure "--basedir=C:\Program Files\MySQL\MySQL Server 8.0" "--datadir=$dataDir" --console
}
if (-not (Get-NetTCPConnection -LocalPort 3308 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $mysqlExe -ArgumentList @('--no-defaults',"--datadir=$dataDir",'--port=3308','--bind-address=127.0.0.1','--mysqlx=0','--skip-log-bin',"--log-error=$(Join-Path $projectDir '.local\mysql.log')") -WindowStyle Hidden
    $ready = $false
    for ($i=0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 300
        if (Get-NetTCPConnection -LocalPort 3308 -State Listen -ErrorAction SilentlyContinue) { $ready=$true; break }
    }
    if (-not $ready) { throw 'The project MySQL server did not start. See .local\mysql.log.' }
}
if (-not (Test-Path -LiteralPath $configFile)) { & $pythonExe (Join-Path $projectDir 'setup_presentation.py') }
if (-not (Get-NetTCPConnection -LocalPort 5080 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $pythonExe -ArgumentList (Join-Path $projectDir 'app.py') -WorkingDirectory $projectDir -WindowStyle Hidden -RedirectStandardOutput (Join-Path $projectDir '.local\app.log') -RedirectStandardError (Join-Path $projectDir '.local\app-error.log')
}
Start-Process 'http://127.0.0.1:5080'
Write-Host 'Campus Ledger is available at http://127.0.0.1:5080'
