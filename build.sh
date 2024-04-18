#!/bin/bash

if [ "$(uname -m)" == "x86_64" ]; then
    export BUILD_CROSS_COMPILE=$(pwd)/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-androidkernel-
elif [ "$(uname -m)" == "aarch64" ]; then
    export BUILD_CROSS_COMPILE=
else
    echo "Unsupported architecture: $(uname -m)"
    exit 1
fi
export BUILD_JOB_NUMBER=$(grep -c ^processor /proc/cpuinfo)
RDIR=$(pwd)

'
MODEL=d2s
export MODEL=d2s
KERNEL_DEFCONFIG=exynos9820-d2s_defconfig
SOC=9825
BOARD=SRPSC14B007KU
'

MODEL=beyondx
export MODEL=beyondx
KERNEL_DEFCONFIG=exynos9820-beyondx_defconfig
SOC=9820
BOARD=SRPSC04B011KU

FUNC_BUILD_KERNEL()
{
    echo " Starting a kernel build using "$KERNEL_DEFCONFIG ""
    # No this is not a typo, samsung left it this way on 12
    export PLATFORM_VERSION=11
    export ANDROID_MAJOR_VERSION=r
        
    make ARCH=arm64 CC=clang CROSS_COMPILE=$BUILD_CROSS_COMPILE -j$BUILD_JOB_NUMBER $KERNEL_DEFCONFIG
    
    make ARCH=arm64 CC=clang CROSS_COMPILE=$BUILD_CROSS_COMPILE -j$BUILD_JOB_NUMBER

if [ "$(uname -m)" == "x86_64" ]; then
    $RDIR/toolchains/mkdtimg cfg_create build/dtb_$SOC.img \
        $RDIR/toolchains/configs/exynos$SOC.cfg \
        -d $RDIR/arch/arm64/boot/dts/exynos
elif [ "$(uname -m)" == "aarch64" ]; then
    mkdtboimg cfg_create build/dtb_$SOC.img \
        $RDIR/toolchains/configs/exynos$SOC.cfg \
        -d $RDIR/arch/arm64/boot/dts/exynos
else
    echo "Unsupported architecture: $(uname -m)"
    exit 1
fi

    echo " Finished kernel build"
}

FUNC_BUILD_DTBO()
{
if [ "$(uname -m)" == "x86_64" ]; then
    $RDIR/toolchains/mkdtimg cfg_create build/dtbo_$MODEL.img \
        $RDIR/toolchains/configs/$MODEL.cfg \
        -d $RDIR/arch/arm64/boot/dts/samsung
elif [ "$(uname -m)" == "aarch64" ]; then
    mkdtboimg cfg_create build/dtbo_$MODEL.img \
        $RDIR/toolchains/configs/$MODEL.cfg \
        -d $RDIR/arch/arm64/boot/dts/samsung
else
    echo "Unsupported architecture: $(uname -m)"
    exit 1
fi
}

FUNC_BUILD_RAMDISK()
{
    rm -f $RDIR/ramdisk/split_img/boot.img-kernel
    cp $RDIR/arch/arm64/boot/Image $RDIR/ramdisk/split_img/boot.img-kernel
    echo $BOARD > ramdisk/split_img/boot.img-board
    # This is kinda ugly hack, we could as well touch .placeholder to all of those
    mkdir -p $RDIR/ramdisk/ramdisk/debug_ramdisk
    mkdir -p $RDIR/ramdisk/ramdisk/dev
    mkdir -p $RDIR/ramdisk/ramdisk/mnt
    mkdir -p $RDIR/ramdisk/ramdisk/proc
    mkdir -p $RDIR/ramdisk/ramdisk/sys

    rm -rf $RDIR/ramdisk/ramdisk/fstab.exynos9820
    rm -rf $RDIR/ramdisk/ramdisk/fstab.exynos9825

    cp $RDIR/ramdisk/fstab.exynos$SOC $RDIR/ramdisk/ramdisk/

    cd $RDIR/ramdisk/
    ./repackimg.sh --nosudo
}

FUNC_BUILD_ZIP()
{
    cd $RDIR/build
    rm -rf $MODEL-boot-ramdisk.img
    mv $RDIR/ramdisk/image-new.img $RDIR/build/$MODEL-boot-ramdisk.img

    # Make recovery flashable package
    rm -rf $RDIR/build/zip
    mkdir -p $RDIR/build/zip
    cp $RDIR/build/$MODEL-boot-ramdisk.img $RDIR/build/zip/boot.img
    cp $RDIR/build/dtb_$SOC.img $RDIR/build/zip/dtb.img
    cp $RDIR/build/dtbo_$MODEL.img $RDIR/build/zip/dtbo.img
    mkdir -p $RDIR/build/zip/META-INF/com/google/android/
    cp $RDIR/toolchains/updater-script $RDIR/build/zip/META-INF/com/google/android/
    cp $RDIR/toolchains/update-binary $RDIR/build/zip/META-INF/com/google/android/
    cd $RDIR/build/zip
    zip -r ../kernel_$MODEL.zip .
    rm -rf $RDIR/build/zip
    cd $RDIR/build
}

# MAIN FUNCTION
rm -rf ./build.log
(
	START_TIME=`date +%s`

	FUNC_BUILD_KERNEL
	FUNC_BUILD_DTBO
	FUNC_BUILD_RAMDISK
	FUNC_BUILD_ZIP

	END_TIME=`date +%s`

	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo "Total compile time was $ELAPSED_TIME seconds"

) 2>&1	| tee -a ./build.log
