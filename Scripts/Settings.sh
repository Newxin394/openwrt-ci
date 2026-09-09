#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# ======================================================
# 网络优化与 NSS 多核调优 (Packet Steering & Sysctl)
# ======================================================
# 1. 默认启用 Packet Steering (多核分流，避免 CPU0 单核打满)
UCI_DEF_DIR="./package/base-files/files/etc/uci-defaults"
mkdir -p "$UCI_DEF_DIR"
cat << 'EOF' > "$UCI_DEF_DIR/99-custom-packet-steering"
#!/bin/sh
uci set network.@globals[0].packet_steering='1'
uci commit network
exit 0
EOF
chmod +x "$UCI_DEF_DIR/99-custom-packet-steering"

# 2. 预置高吞吐与 NSS 协议栈系统参数调优
SYSCTL_DIR="./package/base-files/files/etc/sysctl.d"
mkdir -p "$SYSCTL_DIR"
cat << 'EOF' > "$SYSCTL_DIR/99-nss-tuning.conf"
# NSS & High-Throughput Network Stack Optimization
net.core.netdev_max_backlog = 10000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.netfilter.nf_conntrack_max = 131072
EOF

# 3. 预置 APK 软件源与公钥（支持通过 APK 安装 Sub-Store 与 Nikki 预编译包）
APK_REPO_DIR="./package/base-files/files/etc/apk/repositories.d"
APK_KEYS_DIR="./package/base-files/files/etc/apk/keys"
mkdir -p "$APK_REPO_DIR" "$APK_KEYS_DIR"

cat << 'EOF' > "$APK_REPO_DIR/substore.list"
https://substore-openwrt.pages.dev/openwrt-25.12/all/packages.adb
EOF

cat << 'EOF' > "$APK_REPO_DIR/customfeeds.list"
https://nikkinikki.pages.dev/SNAPSHOT/aarch64_cortex-a53/nikki/packages.adb
EOF

cat << 'EOF' > "$APK_KEYS_DIR/substore-apk.pem"
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEJKvnnTePdD16sK/rksork3HzOxeQ
YJjfM7/Fd1eVSpC7k4I/80OpF8lxuoCMbNilssnMtG2WUv/idDjcIEa+Lw==
-----END PUBLIC KEY-----
EOF

cat << 'EOF' > "$APK_KEYS_DIR/nikki.pem"
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETOwt83tzTFqyvjwimjuuvslR40t6
XnROMwxZsC0iQAr2hHjuXX8qyhf5WaD2Hd897+Gc1/+4W4DMqroNp5w2Dg==
-----END PUBLIC KEY-----
EOF

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
