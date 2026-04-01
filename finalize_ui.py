import os, re

file_path = r"F:\CODE\FastKey\WebUI\index.html"
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

text = re.sub(r'<div class="settings-row".*?<div class="footer">', '<div class="footer">', text, flags=re.DOTALL)

if '.toast-container {' not in text:
    css_patch = """        .btn-secondary {
            background-color: #fff;
            border: 1px solid var(--border-color);
            padding: 10px 24px;
            font-size: 14px;
            font-weight: 900;
            border-radius: 4px;
            cursor: pointer;
            font-family: var(--font-family);
        }

        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.6; }
            100% { opacity: 1; }
        }

        .toast-container {
            position: fixed;
            top: 24px;
            left: 50%;
            transform: translateX(-50%);
            z-index: 9999;
            display: flex;
            flex-direction: column;
            gap: 12px;
            pointer-events: none;
        }

        .toast {
            background-color: #ffffff;
            color: var(--text-main);
            background-image: radial-gradient(var(--border-color) 1px, transparent 1px);
            background-size: 16px 16px;
            border: 1px solid var(--border-color);
            padding: 16px 24px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 700;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
            display: flex;
            align-items: center;
            gap: 12px;
            opacity: 0;
            transform: translateY(-20px);
            transition: all 0.35s cubic-bezier(0.16, 1, 0.3, 1);
            max-width: 400px;
            line-height: 1.6;
        }

        .toast.show {
            opacity: 1;
            transform: translateY(0);
        }

        .toast-icon {
            font-size: 18px;
        }
    </style>"""
    text = re.sub(r'        \.btn-secondary \{.*?</style>', css_patch, text, flags=re.DOTALL)

if 'ShowWarningToast' not in text:
    js_patch = """    <script>
        function postMsg(s) { window.chrome.webview.postMessage(s); }
        let currentDevice = null;
        let mappingsData = [];
        let settings = { autoStart: true };

        // --- UI 增强：Toast 提示 ---
        function ShowWarningToast(msg) {
            const container = document.getElementById('toastContainer');
            const toast = document.createElement('div');
            toast.className = 'toast';
            toast.innerHTML = `<span class="toast-icon">⚠️</span><span>${msg}</span>`;
            container.appendChild(toast);
            
            requestAnimationFrame(() => {
                void toast.offsetWidth;
                toast.classList.add('show');
            });

            setTimeout(() => {
                toast.classList.remove('show');
                setTimeout(() => toast.remove(), 300);
            }, 4500);
        }

        // --- 与 AHK 交互的回调函数 ---"""
    text = re.sub(r'    <script>.*?\/\/ --- 与 AHK 交互的回调函数 ---', js_patch, text, count=1, flags=re.DOTALL)

if 'alert(warning);' in text:
    text = text.replace("""            if (done) {
                const warning = GetReservedHotkeyWarning(hotkey || "");
                if (warning) {
                    alert(warning);
                }
            }""", """            if (done) {
                const warning = GetReservedHotkeyWarning(hotkey || "");
                if (warning) {
                    ShowWarningToast(warning);
                }
            }""")

    text = text.replace("""        function GetReservedHotkeyWarning(hotkey) {
            const normalized = NormalizeHotkeyString(hotkey);
            const warnings = {
                'Alt + Space': 'Alt + Space is a Windows system shortcut and may open the window menu instead of triggering your target app.',
                'Alt + F4': 'Alt + F4 is a Windows system shortcut and may close the active window.',
                'Alt + Tab': 'Alt + Tab is a Windows system shortcut and is not recommended here.',
                'Ctrl + Esc': 'Ctrl + Esc is a Windows system shortcut and is not recommended here.',
                'Win + D': 'Win + D is a Windows system shortcut and is not recommended here.',
                'Win + E': 'Win + E is a Windows system shortcut and is not recommended here.',
                'Win + L': 'Win + L is a Windows system shortcut and will lock the computer.',
                'Win + R': 'Win + R is a Windows system shortcut and is not recommended here.',
                'Win + Tab': 'Win + Tab is a Windows system shortcut and is not recommended here.'
            };
            return warnings[normalized] || '';
        }""", """        function GetReservedHotkeyWarning(hotkey) {
            const normalized = NormalizeHotkeyString(hotkey);
            const reservedKeys = [
                'Alt + Space', 'Alt + F4', 'Alt + Tab', 
                'Ctrl + Esc', 'Win + D', 'Win + E', 
                'Win + L', 'Win + R', 'Win + Tab'
            ];
            
            if (reservedKeys.includes(normalized)) {
                return `已录入系统保留键 <b>${normalized}</b><br>
                        <span style="color:#aaa; font-size:12px;">Windows 会优先拦截它，可能导致无法触发目标动作。建议更换为非系统组合 (例: Ctrl+Alt+Q)</span>`;
            }
            return '';
        }""")

    text = text.replace("""        function SaveConfig(action) {
            for (const row of mappingsData) {
                for (const hotkey of [row.hk1, row.hk2, row.hk3]) {
                    const warning = GetReservedHotkeyWarning(hotkey || "");
                    if (warning) {
                        alert(warning);
                        break;
                    }
                }
            }
            postMsg(action + ':' + GetMappingData());
        }""", """        function SaveConfig(action) {
            let hasWarning = false;
            for (const row of mappingsData) {
                for (const hotkey of [row.hk1, row.hk2, row.hk3]) {
                    const warning = GetReservedHotkeyWarning(hotkey || "");
                    if (warning && !hasWarning) { 
                        ShowWarningToast("保存成功，但配置中包含<b>系统保留快捷键</b>，可能会被 Windows 优先拦截。");
                        hasWarning = true;
                    }
                }
            }
            postMsg(action + ':' + GetMappingData());
        }""")

if '<div class="toast-container"' not in text:
    text = text.replace('<body>', '<body>\n    <div class="toast-container" id="toastContainer"></div>')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)
print("DOM modified successfully")
