# Debug data 폴더 기준 사용자 JSON 동기화·정리 유틸리티
#
# - Setup 번들: installer/bundled_user_data/data/
# - 런타임 전용 JSON(last_execution_time 등)은 번들·Setup에 포함하지 않음
# - Release data 잔여 구버전 JSON은 dist/Setup 빌드 시 제거

$Script:UserDataSyncRoot = Split-Path $PSScriptRoot -Parent

# Setup에 포함할 고정 JSON 파일명
$Script:BundledFixedJsonNames = @(
    'app_settings.json',
    'timetable_file_metadata.json',
    'timetable_theme.json',
    'substitution_plan_data.json',
    'pdf_export_last_selected_template.json',
    'pdf_export_settings_template_0.json'
)

# 앱 실행 시 생성·갱신되는 JSON — Setup 번들에서 제외
$Script:RuntimeOnlyJsonNames = @(
    'last_execution_time.json'
)

function Get-DebugDataDirectory {
    return Join-Path $Script:UserDataSyncRoot 'build\windows\x64\runner\Debug\data'
}

function Get-BundledDataDirectory {
    return Join-Path $Script:UserDataSyncRoot 'installer\bundled_user_data\data'
}

function Get-AllowedBundledJsonNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDataDir
    )

    if (-not (Test-Path $SourceDataDir)) {
        throw "Debug data 폴더를 찾을 수 없습니다: $SourceDataDir`nflutter run -d windows 로 앱을 한 번 실행해 주세요."
    }

    $allowed = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $Script:BundledFixedJsonNames) {
        if (Test-Path (Join-Path $SourceDataDir $name)) {
            $allowed.Add($name)
        }
    }

    Get-ChildItem $SourceDataDir -Filter 'timetable_data_*.json' -ErrorAction SilentlyContinue |
        ForEach-Object { $allowed.Add($_.Name) }

    return $allowed
}

function Sync-BundledUserDataFromDebug {
    $sourceDataDir = Get-DebugDataDirectory
    $bundledDataDir = Get-BundledDataDirectory

    $allowedNames = Get-AllowedBundledJsonNames -SourceDataDir $sourceDataDir
    if ($allowedNames.Count -eq 0) {
        throw "Debug data에 번들할 JSON이 없습니다: $sourceDataDir"
    }

    New-Item -ItemType Directory -Path $bundledDataDir -Force | Out-Null

    foreach ($name in $allowedNames) {
        $src = Join-Path $sourceDataDir $name
        Copy-Item $src (Join-Path $bundledDataDir $name) -Force
        Write-Host "복사: $name"
    }

    # Debug에 없는 구버전 번들 JSON 제거
    $removed = Remove-StaleUserJson -DataDir $bundledDataDir -AllowedNames $allowedNames
    foreach ($name in $removed) {
        Write-Host "삭제(번들 구버전): $name" -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "번들 데이터 동기화 완료 (Debug 기준): installer\bundled_user_data\data\" -ForegroundColor Green
    return $allowedNames
}

function Remove-StaleUserJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataDir,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedNames
    )

    if (-not (Test-Path $DataDir)) {
        return @()
    }

    $removed = @()
    Get-ChildItem $DataDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
        if ($AllowedNames -notcontains $_.Name) {
            Remove-Item $_.FullName -Force
            $removed += $_.Name
        }
    }
    return $removed
}

function Apply-BundledJsonToDataDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDataDir,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedNames
    )

    $bundledDataDir = Get-BundledDataDirectory
    if (-not (Test-Path $bundledDataDir)) {
        throw "bundled_user_data 폴더가 없습니다. Sync-BundledUserDataFromDebug 를 먼저 실행하세요."
    }

    New-Item -ItemType Directory -Path $TargetDataDir -Force | Out-Null

    foreach ($name in $AllowedNames) {
        $src = Join-Path $bundledDataDir $name
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $TargetDataDir $name) -Force
        }
    }

    $removed = Remove-StaleUserJson -DataDir $TargetDataDir -AllowedNames $AllowedNames
    foreach ($name in $removed) {
        Write-Host "  제거(구버전): $name" -ForegroundColor DarkYellow
    }
}
