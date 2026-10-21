#!/usr/bin/env python3
"""给 App 图标抠透明背景。

图像模型（ImageGen 等）输出的 PNG 常常没有 alpha 通道，即使指定 transparent；
直接当图标会在桌面/Dock 露出白色方块。本脚本从四角泛洪填充近白色区域并置为透明，
再对 alpha 做轻微高斯羽化消除锯齿。

用法：
    python3 make_transparent.py 输入.png 输出.png
"""
from PIL import Image, ImageDraw, ImageFilter
import sys

if len(sys.argv) < 3:
    sys.exit("用法：make_transparent.py <输入.png> <输出.png>")

src, dst = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGBA")
w, h = img.size

# 用图标中不存在的洋红色从四边泛洪，标记与外部连通的近白区域
marker = (255, 0, 255, 255)
seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
         (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
for pt in seeds:
    try:
        ImageDraw.floodfill(img, pt, marker, thresh=60)
    except Exception:
        pass

px = img.load()
for y in range(h):
    for x in range(w):
        if px[x, y] == marker:
            px[x, y] = (0, 0, 0, 0)

# 轻微羽化 alpha，避免硬锯齿
alpha = img.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
img.putalpha(alpha)
img.save(dst)
print(f"已保存：{dst}  {img.size}  mode={img.mode}")
