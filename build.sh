#!/bin/bash

rom_fp="$(date +%y%m%d)"
originFolder="$(dirname "$0")"
mkdir -p release/$rom_fp/
set -e

if [ -z "$USER" ];then
	export USER="$(id -un)"
fi
export LC_ALL=C

manifest_url="https://github.com/Havoc-OS-GSI/android_manifest"
havoc="eleven"
phh="android-11.0"

if [ "$release" == true ];then
    [ -z "$version" ] && exit 1
    [ ! -f "$originFolder/release/config.ini" ] && exit 1
fi

repo init -u "$manifest_url" -b $havoc

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

rm -f device/*/sepolicy/common/private/genfs_contexts

(cd device/phh/treble; git clean -fdx; bash generate.sh havoc)

. build/envsetup.sh

buildVariant() {
	lunch $1
	make BUILD_NUMBER=$rom_fp -j$(nproc --all) installclean
	make BUILD_NUMBER=$rom_fp -j$(nproc --all) systemimage
	xz -c $OUT/system.img -T0 > release/$rom_fp/${2}.img.xz
}

    (
	if [ ! -d sas-creator ]; then
        git clone https://github.com/Havoc-OS-GSI/sas-creator
    else
    	cd sas-creator
    	git fetch
    	cd ..
	fi
        cd sas-creator
	if [ ! -d vendor_vndk ]; then
        git clone https://github.com/phhusson/vendor_vndk -b android-10.0
    else
    	cd vendor_vndk
    	git fetch
    	cd ..
	fi
    )
    variant="vanilla"
    if [ "$WITH_GAPPS" == "true" ]; then
    	export TARGET_GAPPS_ARCH=arm64
    	variant="gapps"
	fi
    # ARM64 vanilla {ab, a-only, ab vndk lite}
	buildVariant treble_arm64_bvN-userdebug Havoc-OS-v4.1-$rom_fp-arm64-ab-$variant
    #( cd sas-creator; bash run.sh 64 ; xz -c s.img -T0 > ../release/$rom_fp/system-roar-arm64-aonly-vanilla.img.xz)
    #( cd sas-creator; bash lite-adapter.sh 64; xz -c s.img -T0 > ../release/$rom_fp/system-roar-arm64-ab-vndklite-vanilla.img.xz )

	if [ "$WITH_GAPPS" == "true" ]; then
    	export TARGET_GAPPS_ARCH=arm
    	variant="gapps"
	fi
    # ARM32 vanilla {ab, a-only}
	buildVariant treble_arm_bvS-userdebug Havoc-OS-v4.1-$rom_fp-arm-ab-$variant
    #( cd sas-creator; bash run.sh 32; xz -c s.img -T0 > ../release/$rom_fp/system-roar-arm-aonly-vanilla.img.xz )

    # ARM32_binder64 vanilla {ab, ab vndk lite}
	buildVariant treble_a64_bvS-userdebug Havoc-OS-v4.1-$rom_fp-a64-ab-$variant
    #( cd sas-creator; bash lite-adapter.sh 32; xz -c s.img -T0 > ../release/$rom_fp/system-roar-arm32_binder64-ab-vndklite-vanilla.img.xz)


if [ "$release" == true ];then
    (
        rm -Rf venv
        pip install virtualenv
        export PATH=$PATH:~/.local/bin/
        virtualenv -p /usr/bin/python3 venv
        source venv/bin/activate
        pip install -r $originFolder/release/requirements.txt

        name="AOSP 8.1"
        [ "$build_target" == "android-9.0" ] && name="AOSP 9.0"
        python $originFolder/release/push.py "$name" "$version" release/$rom_fp/
        rm -Rf venv
    )
fi
