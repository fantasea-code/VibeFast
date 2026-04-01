; ============================================================
;  FastKey v2 - Inno Setup packaging script
; ============================================================

[Setup]
AppName=VIBE FAST
AppVersion=2.0
AppPublisher=VIBE FAST
DefaultDirName={localappdata}\VIBE FAST
DefaultGroupName=VIBE FAST
OutputBaseFilename=VIBE_FAST_Setup
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=lowest
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\FastKey.exe
AllowNoIcons=yes
CreateAppDir=yes
OutputDir=Output

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

[Files]
Source: "FastKey.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\FastKey"; Filename: "{app}\FastKey.exe"
Name: "{group}\卸载 FastKey"; Filename: "{uninstallexe}"
Name: "{commondesktop}\FastKey"; Filename: "{app}\FastKey.exe"

[Run]
Filename: "{app}\FastKey.exe"; Description: "立即启动 FastKey"; Flags: postinstall nowait skipifsilent
