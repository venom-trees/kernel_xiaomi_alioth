#!/usr/bin/bash 

CLANG_DIR="/home/venom98/QuetzalKernel/p-clang/bin"
BLDHST="QUETZAL"
DEVICE="alioth"
BVER="EXP"
DEFCONFIG="vendor/alioth_defconfig"


TG_BOT_TOKEN="5330416569:AAE0jza3XIR6xgNrB0fiqVPq4L-RMoJuCbs"
TG_CHAT_ID="-198181011"

# A function to exit on SIGINT.
exit_on_signal_SIGINT() {
    echo -e "\n\n\e[1;31m[✗] Received INTR call - Exiting...\e[0m"
    exit 0
}
trap exit_on_signal_SIGINT SIGINT

tg_sendDocument() {
  curl --progress-bar -o /dev/null -fL \
        -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F "document=@$1" \
        -F "caption=$2" \
        -F "chat_id=$TG_CHAT_ID" \
        -F "disable_web_page_preview=false" \
         #&> /dev/null

#   curl "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
#  -F chat_id="$TG_CHAT_ID" -F document=@"$1" -F caption="$2" } # &> /dev/null
}

tg_sendMessage() {
    curl "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -F chat_id="$TG_CHAT_ID" -F text="$1" -F parse_mode="Markdown"  &> /dev/null
}

kclean() {
    echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
    make clean && make mrproper && rm -rf out/
    echo -e "\n\e[1;32m[✓] Source cleaned and out/ removed! \e[0m"
}

kconfig() {
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64
export DTC_EXT=dtc
export PATH="${CLANG_DIR}:$PATH"
make O=out ARCH=arm64  $DEFCONFIG
#export LD_LIBRARY_PATH="/home/venom98/ven0m98/zeph/prebuilts/clang/host/linux-x86/clang-liyuu/lib:$LD_LIBRARY_PATH" \
}

kmake() {
  make                O=out -j$(nproc --all) Image.gz-dtb  dtbo.img \
                      ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      LLVM=1

}

kcopy() {
cp out/arch/arm64/boot/dtbo.img ./../../zip/Quetzalkernel/
cp out/arch/arm64/boot/dtb.img ./../../zip/Quetzalkernel/
cp out/arch/arm64/boot/Image ./../../zip/Quetzalkernel/
}




kzip() {
	[ ! -d out/ak3 ] && git clone --depth=1 https://github.com/osm0sis/AnyKernel3 out/ak3
	echo -e "
	# AnyKernel3 Ramdisk Mod Script
	# osm0sis @ xda-developers
	properties() { '
	kernel.string=$BLDHST
	device.name1=$DEVICE
	do.devicecheck=1
	do.modules=0
	do.systemless=0
	do.cleanup=1
	do.cleanuponabort=0
	'; }
	block=/dev/block/bootdevice/by-name/boot;
	is_slot_device=0;
	ramdisk_compression=auto;
	patch_vbmeta_flag=auto;
	. tools/ak3-core.sh;
	set_perm_recursive 0 0 755 644 \$ramdisk/*;
	set_perm_recursive 0 0 750 750 \$ramdisk/init* \$ramdisk/sbin;
	dump_boot;
	if [ -d \$ramdisk/overlay ]; then
		rm -rf \$ramdisk/overlay;
	fi;
	write_boot;
	" > out/ak3/anykernel.sh && sed -i "s/\t//g;1d" out/ak3/anykernel.sh
	[ -f out/arch/arm64/boot/Image ] && cp out/arch/arm64/boot/Image out/ak3
	[ -f out/arch/arm64/boot/dtb.img ] && cp out/arch/arm64/boot/dtb.img out/ak3/dtb
	[ -f out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img out/ak3
	mkdir -p out/ak3/vendor_ramdisk out/ak3/vendor_patch
	ZIP_PREFIX_KVER=$(grep Linux out/.config | cut -f 3 -d " ")
	ZIP_POSTFIX_DATE=$(date +%d-%h-%Y-%R:%S | sed "s/:/./g")
	ZIP_PREFIX_STR="$BLDHST-$DEVICE"
	ZIP_BRANCH_VER="$BVER"
	ZIP_FMT=${ZIP_PREFIX_STR}_"${ZIP_BRANCH_VER}"_"${ZIP_POSTFIX_DATE}"
	( cd out/ak3 && zip -r9 ../"${ZIP_FMT}".zip . -x '*.git*' )
        cd out
	tg_sendDocument "${ZIP_FMT}.zip" "$(md5sum "${ZIP_FMT}.zip" | grep -oE "[0-9a-f]{32}")"
}

BGreen='\033[1;32m'
Cyan='\033[0;36m'
Blue='\033[0;34m'
BIGreen='\033[1;92m'
NC='\033[0m'

echo -e "${BIGreen}Perry The Kernel builder${NC}"

if [[ $@ =~ "build" ]]; then

echo -e "${Cyan}Config${NC}"
kconfig

echo -e "${Cyan}Starting Build${NC}"
kmake

echo -e "${Cyan}Making Zip and uploading to Telegram${NC}"
kzip
fi

if [[ $@ =~ "zip" ]]; then
kzip
fi

if [[ $@ =~ "clean" ]]; then
echo -e "${Cyan}Cleaning Sources${NC}"
kclean
fi
