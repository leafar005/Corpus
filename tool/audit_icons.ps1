# Lista todos los iconos Material (Icons.*) usados en el proyecto.
# Uso: powershell -ExecutionPolicy Bypass -File tool\audit_icons.ps1
#      powershell -ExecutionPolicy Bypass -File tool\audit_icons.ps1 -ByFile
#      powershell -ExecutionPolicy Bypass -File tool\audit_icons.ps1 -ExportCsv tool\icons_audit.csv

param(
    [switch]$ByFile,
    [string]$ExportCsv
)

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$pattern = 'Icons\.([a-zA-Z0-9_]+)'

$matches = rg $pattern "$root\lib" "$root\test" "$root\integration_test" --glob "*.dart" -n --no-heading 2>$null

if (-not $matches) {
    Write-Host "No se encontraron iconos Icons.* en el proyecto."
    exit 0
}

$entries = foreach ($line in $matches) {
    if ($line -match '^(.+?):(\d+):(.+)$') {
        $file = $Matches[1] -replace [regex]::Escape($root + '\'), ''
        $lineNum = [int]$Matches[2]
        $content = $Matches[3]
        $iconMatches = [regex]::Matches($content, $pattern)
        foreach ($m in $iconMatches) {
            [PSCustomObject]@{
                Icon     = $m.Groups[1].Value
                File     = $file
                Line     = $lineNum
                Context  = $content.Trim()
            }
        }
    }
}

if ($ExportCsv) {
    $entries | Sort-Object Icon, File, Line | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Exportado a $ExportCsv ($($entries.Count) usos)"
    exit 0
}

if ($ByFile) {
    $entries | Sort-Object File, Line | Format-Table File, Line, Icon, Context -AutoSize -Wrap
    exit 0
}

Write-Host "=== RESUMEN POR ICONO ===" -ForegroundColor Cyan
$entries | Group-Object Icon | Sort-Object Name | ForEach-Object {
    $files = ($_.Group | Select-Object -ExpandProperty File -Unique).Count
    Write-Host ("{0,-40} {1,4} usos en {2,3} archivos" -f $_.Name, $_.Count, $files)
}

Write-Host ""
Write-Host "=== TOTAL ===" -ForegroundColor Cyan
$uniqueIcons = ($entries | Select-Object -ExpandProperty Icon -Unique).Count
$uniqueFiles = ($entries | Select-Object -ExpandProperty File -Unique).Count
Write-Host "$($entries.Count) usos | $uniqueIcons iconos únicos | $uniqueFiles archivos"
Write-Host ""
Write-Host "Tip: usa -ByFile para ver cada ocurrencia, o -ExportCsv ruta.csv para exportar."
