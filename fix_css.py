import os

file_path = r"F:\CODE\FastKey\WebUI\index.html"

with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

target_css = """        .btn-secondary {
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
            /* Make dots smaller (1px radius) and sparser (16px spacing) */
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

start_idx = text.find("        .btn-secondary {")
end_idx = text.find("    </style>") + len("    </style>")

if start_idx != -1 and end_idx != -1:
    new_text = text[:start_idx] + target_css + text[end_idx:]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_text)
    print("Fixed CSS successfully.")
else:
    print("Could not find anchor points.")
