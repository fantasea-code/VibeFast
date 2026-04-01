# FastKey - 外设快捷键重定向工具

将任何 HID 外设（如大疆 Mic Mini 遥控器）的按键映射为自定义快捷键组合。

## 项目结构

```
FastKey/
├── FastKey.ahk             ← 主程序源码（需编译为 FastKey.exe）
├── FastKey.exe              ← 编译后的主程序
├── AutoHotInterception.dll  ← AHI 核心 DLL
├── Lib/                     ← AHI 库文件
│   ├── AutoHotInterception.ahk
│   ├── CLR.ahk
│   └── x64/interception.dll
├── Driver/                  ← Interception 驱动安装器
│   └── install-interception.exe
├── SetupHelper.bat          ← 安装/卸载辅助脚本
├── FastKeySetup.iss         ← Inno Setup 打包脚本
└── config.ini               ← 运行时自动生成的配置文件
```

## 构建步骤

### 前置条件
- 已安装 [AutoHotkey v2](https://www.autohotkey.com/)
- 已安装 [Inno Setup 6](https://jrsoftware.org/isdl.php)
- 已下载 [Interception 驱动](https://github.com/oblitum/Interception/releases) 并将 `install-interception.exe` 放入 `Driver/` 文件夹

### 第一步：编译 FastKey.exe
1. 右键点击 `FastKey.ahk` → 选择 **Compile Script** (或用 Ahk2Exe 编译器)
2. Base File 选择 `AutoHotkey64.exe`（64位）
3. 编译输出为 `FastKey.exe`

### 第二步：打包安装程序
1. 双击 `FastKeySetup.iss` 或用 Inno Setup Compiler 打开
2. 点击 **编译(Build)** → 生成 `Output/FastKey_Setup.exe`

### 第三步：分发
将 `Output/FastKey_Setup.exe` 发送给用户，双击即可一键安装。

## 使用说明

1. **安装**：运行 `FastKey_Setup.exe`，安装完成后重启电脑使驱动生效
2. **配置**：双击桌面上的 FastKey 图标，在界面中选择设备、捕获按键、设置快捷键
3. **运行**：点击"保存并启动"，程序自动最小化到托盘后台运行
4. **管理**：右键点击托盘图标，可以重新配置、暂停拦截或退出
5. **开机自启**：已自动配置，无需手动设置
6. **卸载**：通过 Windows "添加/删除程序" 一键卸载，自动清理驱动和配置
