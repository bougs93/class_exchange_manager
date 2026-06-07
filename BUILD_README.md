# Windows 빌드 및 배포 가이드

**수업 교체 도우미** Windows 릴리즈 빌드, 설치 프로그램(Inno Setup) 생성, 베타 만료일 설정 방법을 설명합니다.

---

## 목차

1. [사전 준비](#사전-준비)
2. [빌드 방식 비교](#빌드-방식-비교)
3. [일반 exe 빌드 (만료일 없음)](#일반-exe-빌드-만료일-없음)
4. [설치 프로그램 빌드 (베타, 만료일 포함)](#설치-프로그램-빌드-베타-만료일-포함)
5. [버전 올리기](#버전-올리기)
6. [베타 만료일 변경](#베타-만료일-변경)
7. [만료 시 동작](#만료-시-동작)
8. [빌드 결과물 위치](#빌드-결과물-위치)
9. [관련 파일](#관련-파일)
10. [개발·테스트](#개발테스트)
11. [문제 해결](#문제-해결)

---

## 사전 준비

### 필수

| 도구 | 용도 | 확인 명령 |
|------|------|-----------|
| Flutter SDK 3.7+ | 앱 빌드 | `flutter --version` |
| Visual Studio 2022 | Windows 네이티브 빌드 | C++ Desktop development 워크로드 |
| Windows 10/11 SDK | exe 컴파일 | Visual Studio Installer |

```powershell
flutter doctor
flutter config --enable-windows-desktop
```

### 설치 프로그램 빌드 시 추가

| 도구 | 용도 | 설치 |
|------|------|------|
| Inno Setup 7 (권장) | Setup.exe 생성 | `winget install --id JRSoftware.InnoSetup.7 -e` |
| Inno Setup 6 (대안) | Setup.exe 생성 | `winget install --id JRSoftware.InnoSetup -e` |

다운로드: https://jrsoftware.org/isdl.php

Inno Setup 7은 winget 설치 시 다음 경로에 설치될 수 있습니다:

```
%LOCALAPPDATA%\Programs\Inno Setup 7\ISCC.exe
```

`build_installer.ps1`은 Inno Setup 7 → 6 순으로 ISCC.exe를 자동 탐색합니다.

---

## 빌드 방식 비교

| 항목 | 일반 exe | 설치 프로그램 (Inno Setup) |
|------|----------|---------------------------|
| **스크립트** | `build_release.ps1` | `build_installer.ps1` |
| **만료일** | 없음 (`expiryDate = null`) | `tool/build_installer.json` 값 적용 |
| **결과물** | `dist\` 폴더 | `dist\` + `installer\output\*.exe` |
| **용도** | 정식 배포, 내부 테스트 | 베타 테스트 배포 |
| **배포 방법** | 폴더 통째로 복사 | Setup.exe 실행 |

```
┌─────────────────────────┐     ┌─────────────────────────┐
│  build_release.ps1      │     │  build_installer.ps1    │
│  (일반 exe)             │     │  (Inno Setup)           │
├─────────────────────────┤     ├─────────────────────────┤
│  dart-define 없음       │     │  EXPIRY_DATE=2027-02-28 │
│         ↓               │     │         ↓               │
│  expiryDate = null      │     │  expiryDate = 설정값    │
│         ↓               │     │         ↓               │
│  dist\ 폴더 배포        │     │  dist\ + Setup.exe      │
└─────────────────────────┘     └─────────────────────────┘
```

만료일은 **소스 코드를 수정하지 않고**, 빌드 명령(`--dart-define`)으로 exe에 컴파일 시점에 박힙니다.

---

## 일반 exe 빌드 (만료일 없음)

정식 배포 또는 만료 제한 없이 사용할 exe를 만들 때 사용합니다.

### PowerShell

```powershell
.\build_release.ps1
```

### CMD

```cmd
build_release.bat
```

### 수동 빌드

```powershell
flutter pub get
flutter build windows --release

# dist 폴더 생성
Remove-Item -Recurse -Force dist -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path dist | Out-Null
Copy-Item -Recurse -Force build\windows\x64\runner\Release\* dist\
```

### 배포

`dist\` 폴더 **전체**를 사용자 PC에 복사합니다. `data\` 폴더와 DLL 파일이 반드시 포함되어야 합니다.

- 실행 파일: `dist\class_exchange_manager.exe`

---

## 설치 프로그램 빌드 (베타, 만료일 포함)

베타 테스트용 Setup.exe를 만들 때 사용합니다. exe와 설치 프로그램 모두 만료일이 적용됩니다.

### PowerShell

```powershell
.\build_installer.ps1
```

### CMD

```cmd
build_installer.bat
```

### 빌드 단계 (스크립트 내부)

1. `tool/sync_bundled_data.ps1` — Debug `data\` → `installer/bundled_user_data/` 동기화
2. `tool/build_installer.json`에서 만료일 읽기
3. `flutter build windows --release --dart-define=EXPIRY_DATE=...`
4. `Release\` → `dist\` 복사 + 번들 JSON 포함 (Excel 제외)
5. Inno Setup으로 `installer\setup.iss` 컴파일

### 초기 시간표 데이터 (Setup.exe에 포함)

| 번들 경로 | 내용 |
|-----------|------|
| `installer/bundled_user_data/data/` | `timetable_data_*.json`, `app_settings.json`, 테마·PDF 설정 등 |

> Excel(.xlsm/.xlsx) 파일은 Setup에 **포함하지 않습니다**. 시간표는 JSON 캐시로 앱 시작 시 자동 로드됩니다.

데이터 갱신 후 Setup 재빌드:

```powershell
.\tool\sync_bundled_data.ps1   # 수동 동기화 (build_installer.ps1 시작 시 자동 실행)
.\build_installer.ps1
```

설치 후 (관리자 설치, 기본 경로):

```
C:\Program Files\Class Exchange Manager\
├── class_exchange_manager.exe
└── data\          ← JSON·시간표 캐시 (사용자 쓰기 권한 부여됨)
```

> 설치 시 **UAC(관리자 승인)** 이 표시됩니다. `PrivilegesRequired=admin` 설정입니다.

### 배포

```
installer\output\수업교체도우미_Setup_0.9.8.exe
```

사용자는 Setup.exe만 실행하면 설치·바로가기 생성·제거 프로그램 등록이 됩니다.

---

## 버전 올리기

앱 버전은 `lib/constants/app_info.dart` 한 곳에서 관리합니다.

```powershell
# 패치 버전 +1 (예: 0.9.8 → 0.9.9), pubspec.yaml 자동 동기화
dart tool/bump_version.dart

# app_info.dart를 수동 수정한 뒤 pubspec만 동기화
dart tool/bump_version.dart sync
```

버전 변경 후 해당 빌드 스크립트를 다시 실행하면 Setup.exe 파일명에도 새 버전이 반영됩니다.

---

## 베타 만료일 변경

`tool/build_installer.json` 파일만 수정합니다.

```json
{
  "EXPIRY_DATE": "2027-02-28"
}
```

| 변경 후 | 적용 대상 |
|---------|-----------|
| `build_installer.ps1` 재실행 | exe + Setup.exe 모두 새 만료일 |
| `build_release.ps1` | 만료일 **없음** (변경 불필요) |

> **참고:** 만료일 `2027-02-28`은 **2027년 2월 28일 0시부터** 만료로 처리됩니다.  
> 2월 28일 하루 종일 사용하려면 `2027-03-01`로 설정하세요.

---

## 만료 시 동작

`build_installer.ps1`로 빌드한 exe / Setup.exe에만 해당합니다.

### 프로그램 실행 시 (만료 후)

앱 시작 시 다이얼로그가 표시되고, **확인** 클릭 시 프로그램이 종료됩니다.

| 항목 | 내용 |
|------|------|
| 제목 | 프로그램 만료 |
| 메시지 | 프로그램 사용 기간이 만료되었습니다. |
| 만료일 표시 | `만료일: 2027-02-28` |
| 추가 안내 | `AppInfo.usageRestriction` (베타·라이선스 안내) |
| 실행 중 재확인 | 5분마다 |

### Setup.exe 설치 시 (만료 후)

Inno Setup에서 설치 자체를 차단합니다.

```
베타 테스트 설치 기간이 만료되었습니다.
만료일: 2027-02-28

새 버전을 받아 주세요.
```

### 만료 30일 이내 (아직 사용 가능)

사용자 UI 다이얼로그는 없고, 개발자 콘솔에만 경고가 출력됩니다.

```
⚠️ 경고: 프로그램 사용 기간이 N일 남았습니다.
```

---

## 빌드 결과물 위치

| 빌드 | 경로 | 설명 |
|------|------|------|
| Flutter 중간 산출물 | `build\windows\x64\runner\Release\` | flutter build 직후 |
| 배포용 폴더 | `dist\` | exe + DLL + data |
| 설치 프로그램 | `installer\output\수업교체도우미_Setup_{버전}.exe` | Inno Setup 결과 |

`dist\`, `installer\output\`은 `.gitignore`에 포함되어 Git에 올라가지 않습니다.

### Release 폴더 구조 (참고)

```
dist\
├── class_exchange_manager.exe   # 메인 실행 파일
├── flutter_windows.dll            # Flutter 엔진
├── *.dll                          # 플러그인 (printing, syncfusion 등)
├── icudtl.dat
└── data\                          # 에셋, 폰트, PDF 템플릿 (필수)
```

---

## 관련 파일

| 파일 | 역할 |
|------|------|
| `build_release.ps1` / `.bat` | 일반 exe 빌드 (만료일 없음) |
| `build_installer.ps1` / `.bat` | 베타 설치 프로그램 빌드 (만료일 포함) |
| `tool/build_installer.json` | 베타 만료일 설정 |
| `tool/bump_version.dart` | 버전 자동 증가·pubspec 동기화 |
| `installer/setup.iss` | Inno Setup 스크립트 |
| `lib/constants/app_info.dart` | 앱 버전, `expiryDate` (dart-define) |

---

## 개발·테스트

### 일반 실행 (만료일 없음)

```powershell
flutter run -d windows
```

### 만료일 포함 실행 (베타 동작 테스트)

```powershell
flutter run -d windows --dart-define=EXPIRY_DATE=2027-02-28
```

### 릴리즈 exe만 빠르게 빌드

```powershell
flutter build windows --release
```

---

## 문제 해결

### `flutter build windows` 실패

- Visual Studio 2022 **Desktop development with C++** 워크로드 설치 확인
- `flutter doctor -v`로 Windows toolchain 확인

### Inno Setup을 찾을 수 없음

```
오류: Inno Setup(ISCC.exe)을 찾을 수 없습니다.
```

→ Inno Setup 7 설치: `winget install --id JRSoftware.InnoSetup.7 -e`  
→ 또는 https://jrsoftware.org/isdl.php  
→ winget 설치 경로: `%LOCALAPPDATA%\Programs\Inno Setup 7\ISCC.exe`

### exe 실행 시 `data` 폴더 오류

`dist\` 또는 설치 폴더에 `data\`가 없으면 실행되지 않습니다. 폴더 전체를 배포하세요.

### VC++ 런타임 오류

일부 PC에서 **Microsoft Visual C++ 2015–2022 Redistributable (x64)** 설치가 필요할 수 있습니다.

### Syncfusion 라이선스

정식 상용 배포 시 Syncfusion Community/Commercial 라이선스 조건을 확인하세요.  
(`lib/constants/app_info.dart`의 `usageRestriction` 참고)

---

## Microsoft Store (참고)

Store 배포는 MSIX 패키지가 필요하며, Inno Setup과는 별도 절차입니다.

```powershell
flutter pub add --dev msix
flutter build windows --release
flutter pub run msix:create
```

Partner Center: https://partner.microsoft.com/dashboard

---

## 빠른 참조

```powershell
# 정식 exe (만료 없음)
.\build_release.ps1

# 베타 Setup.exe (만료일 tool/build_installer.json)
.\build_installer.ps1

# 버전 올리기
dart tool/bump_version.dart
```
