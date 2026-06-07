# Windows 빌드 가이드

프로젝트 루트에서 실행합니다.

## 사전 준비

- Flutter SDK, Visual Studio 2022 (C++ Desktop)
- **Setup 빌드 시 추가:** [Inno Setup 7](https://jrsoftware.org/isdl.php)  
  `winget install --id JRSoftware.InnoSetup.7 -e`

---

## 1. 일반 방식 (exe 폴더 배포)

만료일 없이 `dist\` 폴더를 통째로 배포합니다.

```powershell
.\build_release.ps1
```

또는

```cmd
build_release.bat
```

**결과물:** `dist\` (exe, DLL, `data\` 포함)

**배포:** `dist\` 폴더 전체를 사용자 PC에 복사

---

## 2. Setup 방식 (설치 프로그램)

베타 배포용 Setup.exe를 만듭니다. 만료일이 exe에 포함됩니다.

```powershell
.\build_installer.ps1
```

또는

```cmd
build_installer.bat
```

**결과물**

| 경로 | 설명 |
|------|------|
| `dist\` | 설치에 들어갈 파일 |
| `installer\output\수업교체도우미_Setup_{버전}.exe` | 설치 프로그램 |

**배포:** Setup.exe만 전달 → 사용자가 설치 (기본: `C:\Program Files\Class Exchange Manager\`)

**Setup 빌드 시 참고**

- Debug `data\`의 JSON이 Setup 초기 데이터로 자동 동기화됩니다 (`flutter run -d windows` 실행 후 빌드 권장)
- 만료일 변경: `tool/build_installer.json`의 `EXPIRY_DATE` 수정 후 재빌드

---

## 비교

| | 일반 방식 | Setup 방식 |
|---|-----------|------------|
| 스크립트 | `build_release.ps1` | `build_installer.ps1` |
| 만료일 | 없음 | `tool/build_installer.json` |
| 결과 | `dist\` | `dist\` + Setup.exe |
| 배포 | 폴더 복사 | Setup.exe 실행 |
