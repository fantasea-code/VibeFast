; ============================================================
;  FastKey v2 — Inno Setup 打包脚本
;  无需驱动安装，无需重启
; ============================================================

[Setup]
AppName=FastKey
AppVersion=2.0
AppPublisher=FastKey
DefaultDirName={localappdata}\FastKey
DefaultGroupName=FastKey
OutputBaseFilename=FastKey_Setup
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=admin
SetupIconFile=compiler:SetupClassicIcon.ico
UninstallDisplayIcon={app}\FastKey.exe
AllowNoIcons=yes
CreateAppDir=yes
OutputDir=Output

; 中文界面
[Languages]
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

; 安装的文件（v2 大幅精简：只有 exe + bat）
[Files]
Source: "FastKey.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "SetupHelper.bat"; DestDir: "{app}"; Flags: ignoreversion

; 创建快捷方式
[Icons]
Name: "{group}\FastKey"; Filename: "{app}\FastKey.exe"
Name: "{group}\卸载 FastKey"; Filename: "{uninstallexe}"
Name: "{commondesktop}\FastKey"; Filename: "{app}\FastKey.exe"

; 安装后配置开机自启
[Run]
Filename: "{app}\SetupHelper.bat"; Parameters: "install"; Flags: runhidden waituntilterminated
Filename: "{app}\FastKey.exe"; Description: "立即启动 FastKey"; Flags: postinstall nowait skipifsilent

; 卸载时清理
[UninstallRun]
Filename: "{app}\SetupHelper.bat"; Parameters: "uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "FastKeyCleanup"
