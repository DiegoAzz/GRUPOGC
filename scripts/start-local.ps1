param([switch]$BackendOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localRoot = Join-Path $projectRoot '.local'
$php = Join-Path $localRoot 'php/php.exe'
$mysqlRoot = Join-Path $localRoot 'mysql-8.4.11-winx64'
$mysqld = Join-Path $mysqlRoot 'bin/mysqld.exe'
$dataDir = Join-Path $localRoot 'mysql-data'
foreach ($binary in @($php,$mysqld)) {
    if (!(Test-Path -LiteralPath $binary)) { throw "Falta el componente local: $binary. Consulta README.md." }
}
function Port-Open([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.Connect('127.0.0.1',$port); return $true } catch { return $false } finally { $client.Dispose() }
}
function Wait-Port([int]$port) {
    for ($i=0; $i -lt 60; $i++) { if (Port-Open $port) { return }; Start-Sleep -Milliseconds 500 }
    throw "El puerto $port no respondió. Revisa .local/*.log."
}
function Assert-LocalProcess([string]$name, [string]$binary, [int]$port) {
    if (!(Port-Open $port)) { return }
    $pidPath = Join-Path $localRoot ($name + '.pid')
    if (!(Test-Path -LiteralPath $pidPath)) { throw "El puerto $port ya está ocupado por otro proceso." }
    $savedId = [int](Get-Content -LiteralPath $pidPath)
    $running = Get-Process -Id $savedId -ErrorAction SilentlyContinue
    if (!$running -or $running.Path -ne $binary) { throw "No se puede reutilizar el proceso del puerto $port." }
}
Assert-LocalProcess 'mysql' $mysqld 3307
Assert-LocalProcess 'php' $php 8085
if (!(Test-Path -LiteralPath (Join-Path $dataDir 'mysql'))) {
    & $mysqld --no-defaults --initialize-insecure "--basedir=$mysqlRoot" "--datadir=$dataDir" --console
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo inicializar MySQL local.' }
}
if (!(Port-Open 3307)) {
    $mysqlArgs = @('--no-defaults', ('--basedir="' + $mysqlRoot + '"'), ('--datadir="' + $dataDir + '"'), '--port=3307','--bind-address=127.0.0.1','--mysqlx=OFF','--innodb-buffer-pool-size=64M','--console')
    $process = Start-Process -FilePath $mysqld -ArgumentList $mysqlArgs -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $localRoot 'mysql-out.log') -RedirectStandardError (Join-Path $localRoot 'mysql-error.log')
    Set-Content -LiteralPath (Join-Path $localRoot 'mysql.pid') -Value $process.Id
    Wait-Port 3307
}
& $php (Join-Path $PSScriptRoot 'setup-local.php')
if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar la base local.' }
$env:GRUPO_CG_CONFIG = Join-Path $localRoot 'config.php'
if (!(Port-Open 8085)) {
    $phpArgs = @('-S','127.0.0.1:8085','-t', ('"' + (Join-Path $projectRoot 'backend/public') + '"'))
    $process = Start-Process -FilePath $php -ArgumentList $phpArgs -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $localRoot 'php-out.log') -RedirectStandardError (Join-Path $localRoot 'php-error.log')
    Set-Content -LiteralPath (Join-Path $localRoot 'php.pid') -Value $process.Id
    Wait-Port 8085
}
Write-Host 'API local: http://127.0.0.1:8085/index.php'
Write-Host 'Acceso: admin@grupocg.local / GrupoCG-Local2026! (solo entorno local)'
if ($BackendOnly) { return }
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand)
$dart = Join-Path $flutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
$snapshot = Join-Path $flutterRoot 'bin/cache/flutter_tools.snapshot'
Push-Location $projectRoot
try { & $dart $snapshot run -d chrome --web-hostname=localhost --web-port=5300 --dart-define=API_URL=http://127.0.0.1:8085/index.php }
finally { Pop-Location }
