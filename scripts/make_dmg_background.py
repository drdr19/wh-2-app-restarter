#!/usr/bin/env python3
"""生成 DMG 安装界面背景图（带中文标题与拖拽提示）。

关键点：中文字体必须用 PingFang，用 Helvetica 会渲染成豆腐块（□□□□）。
画布 820×440，左侧约 170px 留空给 Finder 侧边栏遮挡；不要在背景上画与图标对齐的
大色块——真实图标位置一变化就错位，只画渐变 + 标题 + 中间箭头 + 底部提示最稳。

用法：
    python3 make_dmg_background.py [输出路径]
默认输出 assets/dmg-background.png
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 820, 440
out = sys.argv[1] if len(sys.argv) > 1 else "assets/dmg-background.png"

TITLE = "WH-2：应用重启器"
SUBTITLE = "一键关闭并重新打开任意应用"
HINT = "将左侧图标拖入右侧「应用程序」文件夹，即完成安装"

img = Image.new("RGB", (W, H), (238, 243, 250))
d = ImageDraw.Draw(img)

# 垂直渐变
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)],
           fill=(int(238 - t * 70), int(243 - t * 80), int(250 - t * 70)))
d.rectangle([0, 0, W, 3], fill=(255, 255, 255))


def font(size):
    """按优先级找支持中文的字体，Helvetica 兜底（会出豆腐块，仅无中文时退化）。"""
    for p in ["/System/Library/Fonts/PingFang.ttc",
              "/System/Library/Fonts/STHeiti Light.ttc",
              "/System/Library/Fonts/Hiragino Sans GB.ttc",
              "/System/Library/Fonts/Helvetica.ttc"]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


# 标题区从 x=185 起，避开 Finder 侧边栏
d.text((185, 40), TITLE, fill=(35, 60, 95), font=font(34))
d.text((187, 88), SUBTITLE, fill=(105, 125, 155), font=font(16))

# 中间箭头（App 图标在 x≈240-336，Applications 在 x≈540-636）
ay = 290
d.line([(385, ay), (475, ay)], fill=(250, 251, 253), width=6)
d.polygon([(490, ay), (470, ay - 10), (470, ay + 10)], fill=(250, 251, 253))

# 底部提示，在内容居中
hint_font = font(15)
tw = d.textlength(HINT, font=hint_font)
d.text((int(170 + (W - 170 - tw) / 2), H - 56), HINT, fill=(90, 110, 145), font=hint_font)

os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
img.save(out)

# 自检：标题区应有大量深色像素，否则说明中文没渲染出来
px = img.load()
dark = sum(1 for y in range(40, 92) for x in range(185, 500) if sum(px[x, y][:3]) < 400)
print(f"已保存：{out}  {img.size}  标题区深色像素={dark}")
if dark < 200:
    print("⚠️  标题像素过少，可能中文未正常渲染（检查字体路径）")
