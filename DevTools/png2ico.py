from PIL import Image

try:
    img = Image.open('F:/CODE/FastKey/app_icon.png')
    img.save('F:/CODE/FastKey/app_icon.ico', format='ICO', sizes=[(256, 256), (128, 128), (64, 64), (32, 32), (16, 16)])
    print("Success")
except Exception as e:
    print(f"Failed: {e}")
