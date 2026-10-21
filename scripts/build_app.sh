#!/bin/bash
# macOS App 通用构建脚本：双架构编译 → icns 图标 → ad-hoc 签名 → DMG 安装包
#
# 用法（在项目根目录执行）：
#   APP_NAME="你的App名" BUNDLE_ID="cn.example.app" DMG_NAME="YourApp.dmg" bash scripts/build_app.sh
#
# 可选环境变量：
#   SRC_DIR      源码目录，默认 src
#   ICON_PNG     图标源图，默认 assets/icon-1024.png（不存在则跳过图标）
#   DMG_BG       DMG 背景图，默认 assets/dmg-background.png（不存在则用纯背景）
#   MIN_MACOS    最低系统版本，默认 13.0
#   DMG_NAME     DMG 文件名（必须 ASCII！GitHub 会剥离中文），默认 $APP_NAME.dmg
#   SKIP_DMG     =1 只构建 .app，不打包 DMG
#
# 依赖：Xcode Command Line Tools；打包 DMG 需 dmgbuild（pip3 install dmgbuild）
set -euo pipefail

APP_NAME="${APP_NAME:?必须指定 APP_NAME}"
BUNDLE_ID="${BUNDLE_ID:-cn.example.app}"
MIN_MACOS="${MIN_MACOS:-13.0}"
SRC_DIR="${SRC_DIR:-src}"
ICON_PNG="${ICON_PNG:-assets/icon-1024.png}"
DMG_BG="${DMG_BG:-assets/dmg-background.png}"
DMG_NAME="${DMG_NAME:-$APP_NAME.dmg}"
SKIP_DMG="${SKIP_DMG:-0}"

ROOT="$(pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
DIST="$ROOT/dist"

echo "==> 清理旧产物"
rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DIST"

# 别让聚焦搜索索引构建产物，否则会在 Spotlight 里出现和已安装版本重名的副本
touch "$BUILD_DIR/.metadata_never_index"

SOURCES=$(find "$SRC_DIR" -name '*.swift' | tr '\n' ' ')
if [ -z "$SOURCES" ]; then
  echo "❌ 在 $SRC_DIR 下没找到 .swift 文件"; exit 1
fi

echo "==> 编译 arm64"
swiftc -O -target "arm64-apple-macos$MIN_MACOS" -framework Cocoa \
  $SOURCES -o "$BUILD_DIR/app-arm64" 2>&1 | grep -v "warning:" || true

echo "==> 编译 x86_64"
swiftc -O -target "x86_64-apple-macos$MIN_MACOS" -framework Cocoa \
  $SOURCES -o "$BUILD_DIR/app-x86_64" 2>&1 | grep -v "warning:" || true

if [ -f "$BUILD_DIR/app-x86_64" ]; then
  echo "==> 合并通用二进制"
  lipo -create "$BUILD_DIR/app-arm64" "$BUILD_DIR/app-x86_64" \
       -output "$APP/Contents/MacOS/$APP_NAME"
else
  echo "⚠️  x86_64 编译失败，仅保留 arm64（Intel Mac 将无法运行）"
  cp "$BUILD_DIR/app-arm64" "$APP/Contents/MacOS/$APP_NAME"
fi
chmod +x "$APP/Contents/MacOS/$APP_NAME"
lipo -archs "$APP/Contents/MacOS/$APP_NAME"

if [ -f "$ICON_PNG" ]; then
  echo "==> 生成图标 icns（10 个尺寸）"
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
else
  echo "⚠️  未找到 ${ICON_PNG}，跳过图标"
fi

echo "==> 渲染 Info.plist"
TEMPLATE="$(dirname "$0")/../assets/Info.plist.template"
if [ -f "$TEMPLATE" ]; then
  sed -e "s|__EXEC_NAME__|$APP_NAME|g" \
      -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
      -e "s|__MIN_MACOS__|$MIN_MACOS|g" \
      "$TEMPLATE" > "$APP/Contents/Info.plist"
elif [ -f "$SRC_DIR/Info.plist" ]; then
  cp "$SRC_DIR/Info.plist" "$APP/Contents/Info.plist"
else
  echo "❌ 找不到 Info.plist 模板"; exit 1
fi

# 图标键必须是 CFBundleIconFile（CFBundleIconName 只对编译过的 Assets.car 有效）
if [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
fi

echo "==> ad-hoc 签名（arm64 不签名会被系统杀掉）"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"

if [ "$SKIP_DMG" = "1" ]; then
  echo ""
  echo "✅ 完成（仅 App）：$APP"
  exit 0
fi

echo "==> 打包 DMG"
if ! python3 -c "import dmgbuild" 2>/dev/null; then
  echo "❌ 缺少 dmgbuild，请先安装：pip3 install dmgbuild"; exit 1
fi

export APP_NAME DMG_NAME DMG_BG
python3 "$(dirname "$0")/dmgbuild_run.py"

echo ""
echo "✅ 完成：$DIST/$DMG_NAME"
ls -lh "$DIST/$DMG_NAME"
