#!/bin/bash
#
# Wang Bin, Jan 20,2012
#                      wbsecg1@gmail.com

echocheck() {
  echo "Checking for $@ ... "
}

error() {
	echo -e "\e[1;31merror:\e[m $1"
	exit 1
}

show_help(){
cat << EOF
Build script for libav
Wang Bin, Jan 20,2012
wbsecg1@gmail.com
Usage: $0 [patch|help]

EOF
exit 0
}


build_patch() {
cat <<EOF

EOF
  echocheck "new directory"
  new_dir=$(dirname `readlink -f "$0"`)
  echo "new dir is: $new_dir"

  echocheck "original directory"
  test -z $orig_dir && orig_dir=${new_dir%-*}
  test ! -d $orig_dir && orig_dir=$orig_dir.orig
  if test ! -d $orig_dir ;then
    echo "Please input the original directory:";
    read orig_dir
	test ! -d $orig_dir && echo "Can't find original directory: $orig_dir or ${orig_dir%.orig}!" && exit 0
  fi	
  echo "orig dir is: $orig_dir"	

  cd $new_dir
  echo "Cleaning ..."
  make distclean 
  [ -f build.log ] && rm build.log
    
  cd ..
  test -d patches || mkdir -p patches
  echo "Patching ..."
  patch_filename=${new_dir##*/}-`date +%Y%m%d-%H:%M:%S`.patch

  diff -NrubBwE -x "config\.*" -x ".git" -x "*.pc" $orig_dir $new_dir >patches/$patch_filename
  du -h patches/$patch_filename
  echo "Done! Saved to `pwd`/patches/$patch_filename"
}

build_libav() {
SDL_LFLAGS=`pkg-config $ARM_INSTALL/lib/pkgconfig/sdl.pc --libs`
SDL_CFLAGS=`pkg-config $ARM_INSTALL/lib/pkgconfig/sdl.pc --cflags`

#xvid_opt=--enable-libxvid
#freetype_opt=--enable-libfreetype
if [ "x$xfreetype_opt" = "x--enable-libfreetype" ]; then
FREETYPE_LFLAGS=`pkg-config $ARM_INSTALL/lib/pkgconfig/freetype2.pc --libs`
FREETYPE_CFLAGS=`pkg-config $ARM_INSTALL/lib/pkgconfig/freetype2.pc --cflags`
fi
IPP_LIB="$IPPROOT/lib/ippVC_WMMX50LNX_r.a $IPPROOT/lib/ippIP_WMMX50LNX_r.a"
#zlib: 1.2.5. deflateBound().

$(dirname `readlink -f "$0"`)/configure --pkgconfig-dir=$ARM_INSTALL/lib/pkgconfig --prefix=$ARM_INSTALL --host-cc=gcc --enable-cross-compile --cross-prefix=iwmmxt_le- --target-os=linux \
 --sysinclude=$ARM_INSTALL/../include --ld=iwmmxt_le-gcc --arch=armv5te --cpu=iwmmxt  \
 --enable-shared --enable-gpl --enable-version3 --enable-avplay --enable-asm \
 --disable-network --enable-runtime-cpudetect  --enable-hardcoded-tables --disable-indev=v4l --enable-libopencore-amrnb --enable-libopencore-amrwb  --enable-zlib $freetype_opt $xvid_opt \
 $freetype_opt --enable-libmp3lame  --disable-armv5te --enable-iwmmxt  --enable-pic  \
 --extra-cflags="-I$IPPROOT/include -D_REENTRANT -DCONFIG_EZX -Wstrict-prototypes -Wmissing-prototypes -Wundef -Wdisabled-optimization -std=gnu99 \
 -Wall -Wno-switch -Wpointer-arith -Wredundant-decls -O4   -pipe -ffast-math -fomit-frame-pointer -foptimize-sibling-calls -fstrength-reduce \
 -frerun-loop-opt -fforce-mem -fforce-addr -fschedule-insns -fschedule-insns2 -frename-registers -finline-functions -finline-limit=500 \
 -funsafe-math-optimizations -fno-trapping-math -ffinite-math-only $FREETYPE_CFLAGS" \
 --extra-libs="$IPP_LIB -L$ARM_INSTALL/lib $FREETYPE_LFLAGS" --sdl-cflags="$SDL_CFLAGS" --sdl-libs="$SDL_LFLAGS" \
 --disable-debug --enable-extra-warnings \
 |tee cfg.log

[ $? -ne 0 ] && error "configure failed!"
time make -j4 2>&1 |tee build.log
}

:<<NOTE
 
 -DHAVE_IPP
--disable-asm
libopencore-amr:  --enable-version3
--sysroot
--enable-avisynth: require2 vfw32 "windows.h vfw.h" AVIFileInit -lavifil32
 --enable-libx264: 0.118
ld: not support -Wl,-soname,libavutil.so.51, use gcc linker
NOTE


what=$1

if [ "X$what" = "Xpatch" ]; then
  build_patch
else
  build_libav
fi


