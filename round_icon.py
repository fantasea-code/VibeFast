from PIL import Image, ImageDraw

def add_rounded_corners(im, rad):
    # 创建一个抗锯齿的圆角遮罩
    mask = Image.new('L', im.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, im.size[0], im.size[1]), radius=rad, fill=255)
    
    # 转换为 RGBA 以支持透明度
    result = im.convert('RGBA')
    result.putalpha(mask)
    return result

try:
    # 读取你目前选定的方块图标
    img = Image.open('F:/CODE/FastKey/app_icon.png')
    
    # 按比例计算圆角幅度 (22% 的比例类似 iOS 的松鼠圆角风格)
    radius = int(img.width * 0.22)
    rounded_img = add_rounded_corners(img, radius)
    
    # 覆盖保存为纯透明底的 PNG 和 ICO
    rounded_img.save('F:/CODE/FastKey/app_icon.png')
    rounded_img.save('F:/CODE/FastKey/app_icon.ico', format='ICO', sizes=[(256, 256), (128, 128), (64, 64), (32, 32), (16, 16)])
    print("Rounded corners applied successfully.")
except Exception as e:
    print(f"Error: {e}")
