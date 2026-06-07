# 현재 개발 PC의 시간표 JSON·설정을 installer/bundled_user_data/ 로 복사합니다.
# Setup.exe에 초기 데이터(JSON)로 포함됩니다. Excel 파일은 포함하지 않습니다.
#
# 사용: .\tool\sync_bundled_data.ps1
# 소스: build\windows\x64\runner\Debug\data\ (flutter run 으로 사용 중인 data)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

$sourceDataDir = Join-Path $root "build\windows\x64\runner\Debug\data"
$bundledRoot = Join-Path $root "installer\bundled_user_data"
$bundledDataDir = Join-Path $bundledRoot "data"

if (-not (Test-Path $sourceDataDir)) {
    Write-Host "오류: $sourceDataDir 가 없습니다. 먼저 flutter run -d windows 로 앱을 실행해 주세요." -ForegroundColor Red
    exit 1
}

# 복사할 JSON (사용자별·일회성 파일 제외)
$includeJson = @(
    "app_settings.json",
    "timetable_file_metadata.json",
    "timetable_theme.json",
    "substitution_plan_data.json",
    "pdf_export_last_selected_template.json",
    "pdf_export_settings_template_0.json"
)

New-Item -ItemType Directory -Path $bundledDataDir -Force | Out-Null

# 기존 번들 JSON 정리 (timetable_data_*.json)
Get-ChildItem $bundledDataDir -Filter "timetable_data_*.json" -ErrorAction SilentlyContinue | Remove-Item -Force

foreach ($name in $includeJson) {
    $src = Join-Path $sourceDataDir $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $bundledDataDir $name) -Force
        Write-Host "복사: $name"
    } else {
        Write-Host "건너뜀 (없음): $name" -ForegroundColor Yellow
    }
}

Get-ChildItem $sourceDataDir -Filter "timetable_data_*.json" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $bundledDataDir $_.Name) -Force
    Write-Host "복사: $($_.Name)"
}

Write-Host ""
Write-Host "번들 데이터 동기화 완료 (JSON만): installer\bundled_user_data\data\" -ForegroundColor Green
