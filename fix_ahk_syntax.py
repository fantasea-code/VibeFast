import os

file_path = r"F:\CODE\FastKey\FastKey.ahk"
with open(file_path, 'r', encoding='utf-8-sig', errors='ignore') as f:
    text = f.read()

bad_line = 'RegWrite("\\"" A_ScriptFullPath "\\"", "REG_SZ", AUTOSTART_REG_KEY, AUTOSTART_REG_NAME)'
good_line = 'RegWrite("\'"\' A_ScriptFullPath \'"\', "REG_SZ", AUTOSTART_REG_KEY, AUTOSTART_REG_NAME)'

if bad_line in text:
    text = text.replace(bad_line, good_line)
    with open(file_path, 'w', encoding='utf-8-sig') as f:
        f.write(text)
    print("Fixed syntax error.")
else:
    print("Could not find the bad line.")
