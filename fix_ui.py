import os

file_path = r"F:\CODE\FastKey\WebUI\index.html"

with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# The clean target script we want to inject
target_script = """    <script>
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
                void toast.offsetWidth; // 触发重绘
                toast.classList.add('show');
            });

            setTimeout(() => {
                toast.classList.remove('show');
                setTimeout(() => toast.remove(), 300);
            }, 4500);
        }

        // --- 与 AHK 交互的回调函数 ---

        // AHK 传入设备列表
        function UpdateDeviceList(devicesJSON) {
            const devices = JSON.parse(devicesJSON);
            const listEl = document.getElementById('deviceList');
            if (listEl) listEl.innerHTML = '';

            // 构造一个内部索引便于根据 VID PID 获取名字
            window.deviceMap = {};
            devices.forEach(d => window.deviceMap[`${d.vid}_${d.pid}`] = d.name);

            let foundActive = false;

            // 添加“全部映射”选项
            const allBtn = document.createElement('div');
            allBtn.className = 'device-item';
            if (!currentDevice) {"""

# We need to find where the `<script>` tag starts, 
# and where `if (!currentDevice) {` is currently located in the broken file.
start_idx = text.find("<script>")
fallback_end_idx = text.find("if (!currentDevice) {", start_idx)

if start_idx != -1 and fallback_end_idx != -1:
    new_text = text[:start_idx] + target_script + text[fallback_end_idx + len("if (!currentDevice) {"):]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_text)
    print("Fixed successfully.")
else:
    print("Could not find anchor points.")
