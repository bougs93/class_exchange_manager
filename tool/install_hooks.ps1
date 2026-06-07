# Git hook 설치 (Windows PowerShell)
# 사용: .\tool\install_hooks.ps1

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$hookSource = Join-Path $repoRoot "tool\pre-commit"
$hookTarget = Join-Path $repoRoot ".git\hooks\pre-commit"

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Error "Git 저장소가 아닙니다."
    exit 1
}

Copy-Item -Path $hookSource -Destination $hookTarget -Force
Write-Host "pre-commit hook 설치 완료: $hookTarget"
