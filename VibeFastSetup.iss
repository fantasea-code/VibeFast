; ============================================================
;  VibeFast v2 - Inno Setup packaging script
; ============================================================

[Setup]
AppName=VIBE FAST
AppVersion=2.0
AppPublisher=VIBE FAST
DefaultDirName={localappdata}\VIBE FAST
DefaultGroupName=VIBE FAST
OutputBaseFilename=VibeFast_Setup
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=lowest
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\app_icon.ico
AllowNoIcons=yes
CreateAppDir=yes
OutputDir=Output

[Files]
Source: "VibeFast.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "WebView2Loader.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "WebUI\*"; DestDir: "{app}\WebUI"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "_build\AutoHotkey_2.0.21_setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Tasks]
Name: "startmenuicon"; Description: "创建开始菜单快捷方式"; Flags: unchecked
Name: "desktopicon"; Description: "创建桌面快捷方式"; Flags: unchecked

[Icons]
Name: "{group}\VIBE FAST"; Filename: "{code:GetAhkExe}"; Parameters: """{app}\VibeFast.ahk"""; Tasks: startmenuicon
Name: "{group}\卸载 VIBE FAST"; Filename: "{uninstallexe}"
Name: "{commondesktop}\VIBE FAST"; Filename: "{code:GetAhkExe}"; Parameters: """{app}\VibeFast.ahk"""; Tasks: desktopicon

[Run]
Filename: "{tmp}\AutoHotkey_2.0.21_setup.exe"; Description: "安装 AutoHotkey v2 运行环境"; Flags: postinstall waituntilterminated skipifsilent; Check: not IsAhkInstalled
Filename: "{code:GetAhkExe}"; Parameters: """{app}\VibeFast.ahk"""; Description: "立即启动 VIBE FAST"; Flags: postinstall nowait skipifsilent; Check: IsAhkInstalled

[Code]
function TryAhkPath(Path: string): string;
begin
  if FileExists(Path) then
    Result := Path
  else
    Result := '';
end;

function GetAhkExe(Param: string): string;
begin
  Result := TryAhkPath(ExpandConstant('{pf}\AutoHotkey\v2\AutoHotkey64.exe'));
  if Result = '' then
    Result := TryAhkPath(ExpandConstant('{pf}\AutoHotkey\v2.0.21\AutoHotkey64.exe'));
  if Result = '' then
    Result := TryAhkPath(ExpandConstant('{pf}\AutoHotkey\AutoHotkey64.exe'));
end;

function IsAhkInstalled: Boolean;
begin
  Result := GetAhkExe('') <> '';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpReady) and (not IsAhkInstalled) then
    MsgBox(
      '本安装包会先安装 AutoHotkey v2 运行环境，再启动 VIBE FAST。'#13#10#13#10 +
      '如果你已经手动安装了 AutoHotkey，可以继续直接安装。',
      mbInformation,
      MB_OK
    );
end;
