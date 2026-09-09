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

echo "=========================================="
echo "PRIVATE.sh completed successfully."
echo "=========================================="
