import os

filepath = r"F:\CODE\FastKey\FastKey.ahk"

with open(filepath, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()

if content and "app_icon.ico" not in content:
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if line.strip() == "Persistent":
            lines.insert(i+1, 'TraySetIcon(A_ScriptDir "\\app_icon.ico")')
            lines.insert(i+1, ';@Ahk2Exe-SetMainIcon app_icon.ico')
            break
    
    with open(filepath, "w", encoding="utf-8-sig") as f:
        f.write('\n'.join(lines))
    print("Injected successfully.")
else:
    print("Already injected or empty.")
