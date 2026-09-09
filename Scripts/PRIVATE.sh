#!/bin/bash
# SPDX-License-Identifier: MIT
# Custom private extensions script

echo "=========================================="
echo " Running Custom PRIVATE.sh Extension Script "
echo "=========================================="

# 1. 移除 HomeProxy 源码以加快构建并跳过冗余资源下载
rm -rf ./packages/luci-app-homeproxy ./luci-app-homeproxy 2>/dev/null || true

# 2. 安装 Lucky (官方作者 gdy666/luci-app-lucky，同时包含 lucky 核心与 luci-app-lucky)
echo "Installing Lucky (gdy666/luci-app-lucky)..."
for NAME in "lucky" "luci-app-lucky"; do
	FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)
	if [ -n "$FOUND_DIRS" ]; then
		while read -r DIR; do
			rm -rf "$DIR"
			echo "Deleted feed directory: $DIR"
		done <<< "$FOUND_DIRS"
	fi
done

git clone --depth=1 --single-branch --branch main "https://github.com/gdy666/luci-app-lucky.git" ./tmp-lucky
if [ -d "./tmp-lucky/luci-app-lucky" ]; then
	cp -rf ./tmp-lucky/luci-app-lucky ./
fi
if [ -d "./tmp-lucky/lucky" ]; then
	cp -rf ./tmp-lucky/lucky ./
fi
rm -rf ./tmp-lucky
echo "Lucky installed successfully."

# 3. 安装 Sub-Store (LuCI 插件版)
echo "Installing Sub-Store (luci-app-substore)..."
rm -rf ./luci-app-substore
mkdir -p ./luci-app-substore/root

SUBSTORE_PKG_URL=$(curl -sL "https://substore-openwrt.pages.dev/openwrt-24.10/all/Packages" 2>/dev/null | grep -oP '^Filename: \K.*' | head -n 1)
[ -z "$SUBSTORE_PKG_URL" ] && SUBSTORE_PKG_URL="luci-app-substore_2026.09.09-r1_all.ipk"

curl -sL "https://substore-openwrt.pages.dev/openwrt-24.10/all/$SUBSTORE_PKG_URL" -o /tmp/substore.ipk
if [ -s /tmp/substore.ipk ]; then
	tar -zxf /tmp/substore.ipk ./data.tar.gz -O | tar -zxf - -C ./luci-app-substore/root
	rm -f /tmp/substore.ipk
	echo "Sub-Store extracted successfully."
else
	echo "WARNING: Failed to download Sub-Store IPK package!"
fi

# 确保脚本具有可执行权限
chmod +x ./luci-app-substore/root/etc/init.d/* ./luci-app-substore/root/usr/libexec/substore/*.sh 2>/dev/null || true

# 预置 APK 仓库与公钥（使刷机后 APK 包管理器原生支持 Sub-Store 与 Nikki 源）
mkdir -p ./luci-app-substore/root/etc/apk/repositories.d ./luci-app-substore/root/etc/apk/keys

cat << 'EOF' > ./luci-app-substore/root/etc/apk/repositories.d/substore.list
https://substore-openwrt.pages.dev/openwrt-25.12/all/packages.adb
EOF

cat << 'EOF' > ./luci-app-substore/root/etc/apk/repositories.d/customfeeds.list
# add your custom package feeds here
#
# http://www.example.com/path/to/files/packages.adb
https://nikkinikki.pages.dev/SNAPSHOT/aarch64_cortex-a53/nikki/packages.adb
EOF

cat << 'EOF' > ./luci-app-substore/root/etc/apk/keys/substore-apk.pem
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEJKvnnTePdD16sK/rksork3HzOxeQ
YJjfM7/Fd1eVSpC7k4I/80OpF8lxuoCMbNilssnMtG2WUv/idDjcIEa+Lw==
-----END PUBLIC KEY-----
EOF

cat << 'EOF' > ./luci-app-substore/root/etc/apk/keys/nikki.pem
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETOwt83tzTFqyvjwimjuuvslR40t6
XnROMwxZsC0iQAr2hHjuXX8qyhf5WaD2Hd897+Gc1/+4W4DMqroNp5w2Dg==
-----END PUBLIC KEY-----
EOF

# 创建标准的 OpenWrt LuCI Makefile
cat << 'EOF' > ./luci-app-substore/Makefile
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-substore
PKG_VERSION:=2026.09.09
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for Sub-Store (Subscription Manager)
LUCI_DEPENDS:=+node +unzip +wget-ssl
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/substore
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF

echo "luci-app-substore package configured successfully."
echo "=========================================="
