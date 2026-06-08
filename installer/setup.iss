; 수업 교체 도우미 - Inno Setup 스크립트
; build_installer.ps1 가 MyAppVersion, EXPIRY_DATE 를 /D 옵션으로 전달합니다.

#ifndef MyAppVersion
  #define MyAppVersion "0.9.8"
#endif
#ifndef EXPIRY_DATE
  #define EXPIRY_DATE "2027-02-28"
#endif

#define MyAppName "수업 교체 도우미"
#define MyAppFolder "Class Exchange Manager"
#define MyAppExeName "class_exchange_manager.exe"
#define SourceDir "..\dist"

[Setup]
AppId={{A3B8C2D1-4E5F-6789-ABCD-EF0123456789}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
DefaultDirName={autopf}\{#MyAppFolder}
DefaultGroupName={#MyAppName}
OutputDir=output
OutputBaseFilename=수업교체도우미_Setup_{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; 관리자 권한 설치 → 모든 사용자, 기본 경로 C:\Program Files\Class Exchange Manager
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=..\windows\runner\resources\app_icon.ico
DisableProgramGroupPage=yes
; 제거 시 실행 중 프로세스 처리는 [Code] InitializeUninstall 에서 안내 후 종료
CloseApplications=no
RestartApplications=no

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "바탕 화면에 바로가기 만들기"; GroupDescription: "추가 작업:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Dirs]
; Program Files 설치 시에도 사용자 JSON·설정 저장 가능하도록 data 폴더 쓰기 권한 부여
Name: "{app}\data"; Permissions: users-modify

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName} 실행"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 실행 중 생성된 JSON·캐시 (last_execution_time.json 등 설치 목록 외 파일 포함)
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\data\*.json"
Type: files; Name: "{app}\*.json"
Type: files; Name: "{app}\*.dll"
Type: files; Name: "{app}\*.exe"
; 설치 폴더 전체 (잔여 파일·하위 폴더·빈 폴더 방지)
Type: filesandordirs; Name: "{app}"

[Code]
// 실행 중인 앱 프로세스 확인
function IsAppRunning(): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if Exec('cmd.exe',
    '/C tasklist /FI "IMAGENAME eq {#MyAppExeName}" /NH | find /I "{#MyAppExeName}"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := (ResultCode = 0);
end;

// 프로세스 강제 종료 (설치·업그레이드용 — 메시지 없음)
procedure KillAppIfRunning();
var
  ResultCode: Integer;
begin
  if not IsAppRunning() then
    Exit;
  Exec('taskkill.exe', '/F /IM {#MyAppExeName} /T', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  Sleep(800);
end;

// 제거 시: 실행 중이면 안내 → 사용자 확인 → 종료
function StopAppForUninstall(): Boolean;
var
  ResultCode: Integer;
  RetryCount: Integer;
begin
  Result := True;
  if not IsAppRunning() then
    Exit;

  if MsgBox(
    '{#MyAppName}이(가) 현재 실행 중입니다.' + #13#10 + #13#10 +
    '제거를 계속하려면 프로그램을 종료해야 합니다.' + #13#10 +
    '지금 종료하시겠습니까?',
    mbConfirmation, MB_YESNO) = IDNO then
  begin
    MsgBox('제거가 취소되었습니다.', mbInformation, MB_OK);
    Result := False;
    Exit;
  end;

  Exec('taskkill.exe', '/F /IM {#MyAppExeName} /T', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  Sleep(1000);

  RetryCount := 0;
  while IsAppRunning() and (RetryCount < 6) do
  begin
    Sleep(500);
    Inc(RetryCount);
  end;

  if IsAppRunning() then
  begin
    MsgBox(
      '프로그램을 종료하지 못했습니다.' + #13#10 + #13#10 +
      '작업 관리자에서 {#MyAppName}을(를) 직접 종료한 뒤' + #13#10 +
      '다시 제거를 시도해 주세요.',
      mbError, MB_OK);
    Result := False;
  end;
end;

// YYYY-MM-DD → YYYYMMDD 정수 (Inno Setup 6/7 공통 호환)
function DateStringToInt(const DateStr: String): Integer;
var
  Sep1, Sep2: Integer;
  YearStr, MonthStr, DayStr: String;
begin
  Result := 0;
  Sep1 := Pos('-', DateStr);
  if Sep1 = 0 then Exit;

  Sep2 := Pos('-', Copy(DateStr, Sep1 + 1, MaxInt));
  if Sep2 = 0 then Exit;

  YearStr := Copy(DateStr, 1, Sep1 - 1);
  MonthStr := Copy(DateStr, Sep1 + 1, Sep2 - 1);
  DayStr := Copy(DateStr, Sep1 + Sep2 + 1, MaxInt);

  Result := StrToInt(YearStr) * 10000 + StrToInt(MonthStr) * 100 + StrToInt(DayStr);
end;

// 제거 마무리: 설치 폴더를 통째로 삭제 (런타임 생성 파일·빈 폴더 잔류 방지)
procedure ForceRemoveAppDirectory();
var
  AppDir: String;
begin
  AppDir := ExpandConstant('{app}');
  if not DirExists(AppDir) then
    Exit;

  DelTree(AppDir, True, True, True);

  if DirExists(AppDir) then
    RemoveDir(AppDir);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  case CurUninstallStep of
    usUninstall:
      KillAppIfRunning();
    usPostUninstall:
      ForceRemoveAppDirectory();
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := StopAppForUninstall();
end;

function InitializeSetup(): Boolean;
var
  ExpiryInt, TodayInt: Integer;
  ExpiryStr, TodayStr: String;
begin
  KillAppIfRunning();

  ExpiryStr := '{#EXPIRY_DATE}';
  if ExpiryStr <> '' then
  begin
    ExpiryInt := DateStringToInt(ExpiryStr);
    TodayStr := GetDateTimeString('yyyy-mm-dd', '-', ':');
    TodayInt := DateStringToInt(TodayStr);
    if (ExpiryInt > 0) and (TodayInt > ExpiryInt) then
    begin
      MsgBox(
        '베타 테스트 설치 기간이 만료되었습니다.' + #13#10 +
        '만료일: ' + ExpiryStr + #13#10#13#10 +
        '새 버전을 받아 주세요.',
        mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;
