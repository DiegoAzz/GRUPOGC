param([string]$BaseHref = '/grupocg/')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    flutter build web --release --base-href=$BaseHref --no-tree-shake-icons --pwa-strategy=none
    if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación web.' }
    $webRoot = Join-Path $projectRoot 'build/web'
    # Use the complete font under a content-specific URL to avoid stale subsets.
    $fontPath = Join-Path $webRoot 'assets/fonts/MaterialIcons-Regular.otf'
    $fontHash = (Get-FileHash -LiteralPath $fontPath -Algorithm SHA256).Hash.Substring(0, 12)
    $fontName = "MaterialIcons-$fontHash.otf"
    Copy-Item -LiteralPath $fontPath -Destination (Join-Path $webRoot "assets/fonts/$fontName")
    $manifestPath = Join-Path $webRoot 'assets/FontManifest.json'
    $manifest = [IO.File]::ReadAllText($manifestPath).Replace('fonts/MaterialIcons-Regular.otf', "fonts/$fontName")
    [IO.File]::WriteAllText($manifestPath, $manifest, [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $projectRoot 'web/.htaccess') -Destination $webRoot
    $apiRoot = Join-Path $webRoot 'api'
    New-Item -ItemType Directory -Path $apiRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'backend/public/index.php') -Destination $apiRoot
    Copy-Item -LiteralPath (Join-Path $projectRoot 'backend/public/.htaccess') -Destination $apiRoot
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipPath = Join-Path $projectRoot 'build/GRUPOCG-ICONOS-20261007.zip'
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath }
    $archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $webRoot -Recurse -File -Force | ForEach-Object {
            $entryName = $_.FullName.Substring($webRoot.Length + 1).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entryName) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
    Write-Output "Actualización lista: $zipPath"
} finally {
    Pop-Location
}
