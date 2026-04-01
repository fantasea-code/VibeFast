@echo off
setlocal
:: ============================================================
::  FastKey v2 安装辅助脚本
::  仅处理开机自启动任务（不再需要安装驱动）
:: ============================================================

if "%~1"=="install" goto :install
if "%~1"=="uninstall" goto :uninstall
echo 用法: SetupHelper.bat [install^|uninstall]
exit /b 1

:install
echo [FastKey] 正在配置开机自启动...
schtasks /create /tn "FastKey_AutoStart" /tr "\"%~dp0FastKey.exe\" /background" /sc onlogon /rl highest /f >nul 2>&1
if %errorlevel% equ 0 (
    echo [FastKey] 开机自启动已配置成功。
) else (
    echo [FastKey] 注意：开机自启动配置需要管理员权限。
)
exit /b 0

:uninstall
echo [FastKey] 正在清理...
:: 停止运行中的 FastKey
taskkill /f /im "FastKey.exe" >nul 2>&1
:: 删除开机自启动任务
schtasks /delete /tn "FastKey_AutoStart" /f >nul 2>&1
:: 清理配置文件
if exist "%~dp0config.ini" del "%~dp0config.ini" >nul 2>&1
echo [FastKey] 清理完成。
exit /b 0
