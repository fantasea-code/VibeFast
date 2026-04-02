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
UninstallDisplayIcon={app}\VibeFast.exe
AllowNoIcons=yes
CreateAppDir=yes
OutputDir=Output

[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

[Files]
Source: "VibeFast.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\VIBE FAST"; Filename: "{app}\VibeFast.exe"
Name: "{group}\卸载 VIBE FAST"; Filename: "{uninstallexe}"
Name: "{commondesktop}\VIBE FAST"; Filename: "{app}\VibeFast.exe"

[Run]
Filename: "{app}\VibeFast.exe"; Description: "立即启动 VIBE FAST"; Flags: postinstall nowait skipifsilent
