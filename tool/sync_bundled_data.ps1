# Debug data → installer/bundled_user_data/ 동기화
# 사용: .\tool\sync_bundled_data.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'user_data_sync.ps1')

try {
    Sync-BundledUserDataFromDebug | Out-Null
    exit 0
} catch {
    Write-Host "오류: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
