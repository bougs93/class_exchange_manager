# Git hook 활성화 (Windows PowerShell)
#
# Cursor 커밋 버튼 경로는 %USERPROFILE%\.git-wrapper\universal-git.exe 래퍼가
# <repo>\scripts\hooks\pre-commit.bat 컨벤션으로 처리하므로, 터미널 커밋도
# 같은 훅을 쓰도록 core.hooksPath 만 지정하면 된다.
#
# 사용: .\tool\install_hooks.ps1

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Error "Git 저장소가 아닙니다."
    exit 1
}
if (-not (Test-Path (Join-Path $repoRoot "scripts\hooks\pre-commit.bat"))) {
    Write-Error "scripts\hooks\pre-commit.bat 가 없습니다."
    exit 1
}

Push-Location $repoRoot
try {
    git config core.hooksPath scripts/hooks
    Write-Host "core.hooksPath = scripts/hooks 설정 완료"
} finally {
    Pop-Location
}
