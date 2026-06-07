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

[Code]
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

function InitializeSetup(): Boolean;
var
  ExpiryInt, TodayInt: Integer;
  ExpiryStr, TodayStr: String;
begin
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
