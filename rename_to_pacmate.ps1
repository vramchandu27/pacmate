$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "=== PacMate rename script ===" -ForegroundColor Cyan

$files = @(
    "lib\features\auth\screens\signup_screen.dart",
    "lib\features\hotels\screens\hotel_detail_screen.dart",
    "lib\features\hotels\screens\hotel_finder_screen.dart",
    "lib\features\subscriptions\screens\paywall_screen.dart",
    "test\widget_test.dart",
    "web\manifest.json",
    "README.md",
    "CLAUDE.md",
    "CLAUDE_FIREBASE_API.md"
)

foreach ($file in $files) {
    $path = Join-Path $root $file
    if (-Not (Test-Path $path)) {
        Write-Host "  SKIP (not found): $file" -ForegroundColor Yellow
        continue
    }

    $content = Get-Content $path -Raw -Encoding UTF8
    $original = $content

    $content = $content.Replace("PackMate", "PacMate")
    $content = $content.Replace("Packmate", "PacMate")
    $content = $content.Replace("packmate", "pacmate")

    if ($content -ne $original) {
        Set-Content $path $content -Encoding UTF8 -NoNewline
        Write-Host "  PATCHED: $file" -ForegroundColor Green
    } else {
        Write-Host "  CLEAN:   $file" -ForegroundColor Gray
    }
}

$oldPath = Join-Path $root "android\app\src\main\kotlin\com\example\packmate"
$newPath = Join-Path $root "android\app\src\main\kotlin\com\example\pacmate"

if (Test-Path $oldPath) {
    if (Test-Path $newPath) {
        Write-Host "  SKIP folder rename - pacmate folder already exists" -ForegroundColor Yellow
    } else {
        Rename-Item -Path $oldPath -NewName "pacmate"
        Write-Host "  RENAMED: kotlin/.../packmate -> pacmate" -ForegroundColor Green
    }
} else {
    Write-Host "  SKIP folder rename - packmate folder not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Run flutter pub get to refresh." -ForegroundColor Cyan
