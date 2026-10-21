#!/usr/bin/env python3
"""根据环境变量生成 DMG 布局并调用 dmgbuild。

由 build_app.sh 调用，也可单独用：
    APP_NAME="Foo" DMG_NAME="Foo.dmg" python3 scripts/dmgbuild_run.py

环境变量：APP_NAME（必需）、DMG_NAME、DMG_BG（可选背景图）
说明：窗口宽 820、左侧 170px 预留给 Finder 侧边栏，避免背景图被遮住。
"""
import os
import sys
import dmgbuild

app_name = os.environ.get("APP_NAME")
if not app_name:
    sys.exit("缺少 APP_NAME 环境变量")

dmg_name = os.environ.get("DMG_NAME") or f"{app_name}.dmg"
bg = os.environ.get("DMG_BG", "")

app_path = os.path.join("build", f"{app_name}.app")
if not os.path.isdir(app_path):
    sys.exit(f"找不到 App：{app_path}")

settings = {
    "format": "UDBZ",
    "files": [app_path],
    "symlinks": {"Applications": "/Applications"},
    "default_view": "icon-view",
    "show_icon_preview": False,
    "icon_size": 96,
    "text_size": 14,
    "include_icon_view_settings": True,
    "include_list_view_settings": False,
}

if bg and os.path.isfile(bg):
    settings["background"] = bg
    settings["window_rect"] = ((200, 200), (820, 440))
    settings["icon_locations"] = {
        app_name + ".app": (240, 230),
        "Applications": (540, 230),
        ".background": (0, 0),
    }
else:
    # 无背景图时用更紧凑的窗口，图标左中对齐
    settings["window_rect"] = ((200, 200), (660, 380))
    settings["icon_locations"] = {
        app_name + ".app": (150, 190),
        "Applications": (450, 190),
    }

out = os.path.join("dist", dmg_name)
os.makedirs("dist", exist_ok=True)
print(f"==> dmgbuild 输出：{out}")
dmgbuild.build_dmg(out, app_name, settings=settings)
