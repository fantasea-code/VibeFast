import os

file_path = r"F:\CODE\FastKey\WebUI\index.html"
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# Update .footer CSS to have fixed height
text = text.replace(
"""        .footer {
            padding: 16px 40px;
            border-top: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
            background-color: #fafafa;
        }""",
"""        .footer {
            height: 76px;
            box-sizing: border-box;
            padding: 0 40px;
            border-top: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
            background-color: #fafafa;
            flex-shrink: 0;
        }"""
)

# Update the inline style of the left footer to match height exactly.
# It is currently: <div class="sidebar-footer" style="padding: 16px 20px; border-top: 1px solid var(--border-color); display: flex; align-items: center; justify-content: space-between; background-color: #fafafa; flex-shrink: 0; min-height: 64px; box-sizing: border-box;">
text = text.replace(
"""<div class="sidebar-footer" style="padding: 16px 20px; border-top: 1px solid var(--border-color); display: flex; align-items: center; justify-content: space-between; background-color: #fafafa; flex-shrink: 0; min-height: 64px; box-sizing: border-box;">""",
"""<div class="sidebar-footer" style="height: 76px; padding: 0 20px; border-top: 1px solid var(--border-color); display: flex; align-items: center; justify-content: space-between; background-color: #fafafa; flex-shrink: 0; box-sizing: border-box;">"""
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)

print("Aligned heights successfully.")
