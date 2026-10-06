# Generates lib/widgets/corpus_icon_kind.dart from audit_icons.ps1 output.
param(
    [string]$OutFile = "lib/widgets/corpus_icon_kind.dart"
)

function To-PascalCase([string]$snake) {
    $parts = $snake -split '_'
    return ($parts | ForEach-Object {
        if ($_.Length -eq 0) { return '' }
        $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
    }) -join ''
}

$auditOutput = & "$PSScriptRoot\audit_icons.ps1" 2>&1 | Out-String
$names = [System.Collections.Generic.List[string]]::new()
foreach ($line in ($auditOutput -split "`n")) {
    if ($line -match '^\s*([a-z][a-z0-9_]*)\s+\d+\s+usos') {
        [void]$names.Add($Matches[1])
    }
}
$unique = $names | Sort-Object -Unique

$enumValues = $unique | ForEach-Object { "  $(To-PascalCase $_)," }

$content = @"
/// Semantic icon identifiers for Corpus Tabler SVG icons.
/// Replaces Material [Icons] throughout the app.
enum CorpusIconKind {
$($enumValues -join "`n")
}
"@

$root = Split-Path $PSScriptRoot -Parent
$path = Join-Path $root $OutFile
Set-Content -Path $path -Value $content -Encoding UTF8
Write-Host "Wrote $($unique.Count) kinds to $path"
