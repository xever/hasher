#!/bin/bash
# ============================================================================
# 打包脚本：把 Hasher 编译成通用的 .app 应用
# ----------------------------------------------------------------------------
# 用法：  ./scripts/build-app.sh
# 产物：  dist/Hasher.app
#
# 说明：
#   - 同时编译 arm64 和 x86_64 两种架构，生成“通用二进制”(Universal Binary)，
#     在 Intel 和 Apple Silicon 的 Mac 上都能运行；
#   - 最低支持 macOS 15（由 Package.swift 里的 platforms 决定）。
# ============================================================================

set -euo pipefail

# 切换到项目根目录（本脚本位于 scripts/ 子目录下）
cd "$(dirname "$0")/.."

APP_NAME="Hasher"
APP_DIR="dist/${APP_NAME}.app"

echo "==> 编译通用二进制（arm64 + x86_64）..."
swift build -c release --arch arm64 --arch x86_64

# 通过 swift build --show-bin-path 拿到产物目录（与上面的编译参数保持一致）
BIN_DIR="$(swift build --show-bin-path -c release --arch arm64 --arch x86_64)"
BIN_SRC="${BIN_DIR}/${APP_NAME}"
if [[ ! -f "$BIN_SRC" ]]; then
    echo "错误：未找到编译产物 ${BIN_SRC}" >&2
    exit 1
fi
echo "==> 找到二进制：${BIN_SRC}"

# 资源包（本地化语言文件，与二进制在同一目录下）
RES_BUNDLE="Hasher_Hasher.bundle"
RES_SRC="${BIN_DIR}/${RES_BUNDLE}"

echo "==> 创建 .app 目录结构 ..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "==> 复制二进制 ..."
cp "$BIN_SRC" "$APP_DIR/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_DIR/Contents/MacOS/${APP_NAME}"

echo "==> 复制本地化资源 ..."
if [[ -n "$RES_SRC" ]]; then
    cp -R "$RES_SRC" "$APP_DIR/Contents/Resources/"
else
    echo "    警告：未找到资源包 ${RES_BUNDLE}，语言文件可能缺失"
fi

echo "==> 复制应用图标 ..."
ICON_SRC="Sources/Hasher/Resources/logo.icns"
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/logo.icns"
else
    echo "    警告：未找到图标 ${ICON_SRC}，将使用默认图标"
fi

echo "==> 写入 Info.plist ..."
cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Hasher</string>
    <key>CFBundleDisplayName</key>
    <string>Hasher</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.hasher</string>
    <key>CFBundleExecutable</key>
    <string>Hasher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>logo</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

# 可选：做一次 ad-hoc 签名，避免在部分系统上被 Gatekeeper 拦截
echo "==> Ad-hoc 签名 ..."
codesign --force --deep --sign - "$APP_DIR" || true

echo "==> 完成：$APP_DIR"
echo "    可直接双击运行，或用命令：open $APP_DIR"
