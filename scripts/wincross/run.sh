#!/bin/bash
# Inside the onair-wincross container: cross-compile the Windows dependencies OnAir needs for a HackRF-only build (libusb, GLFW,
# libhackrf, the AVS+-patched FFmpeg) with OnAir's own script, then OnAir itself (dect2.exe, dect2cli.exe, test_ts.exe) and a
# decoder check, and run the test programs under Wine.
# Mounts: /src = OnAir tree (read-only), /avs = the avsplus folder (read-only), /prefix and /work = scratch (read-write).
set -e
export ONAIR_WIN_PREFIX=/prefix ONAIR_WIN_WORK=/work/deps HOME=/work/home WINEDEBUG=-all
mkdir -p /work/deps /work/home
DEPS=/src/tools/package/cross_deps_windows.sh
END=$(awk '/step ffmpeg/{f=1} f && /make install >\/dev\/null\); }/{print NR; exit}' "$DEPS")
echo "=== dependencies: lines 1-$END of cross_deps_windows.sh (libusb, glfw, libhackrf, ffmpeg)"
# the script finds the OnAir tree from its own location, so the shortened copy lives in a writable mirror of that tree
R=/work/src
mkdir -p $R/tools/package
ln -sfn /src/build-windows-deps $R/build-windows-deps
ln -sfn /src/packaging $R/packaging
ln -sfn /src/tools/package/patches $R/tools/package/patches
sed -n "1,${END}p" "$DEPS" > $R/tools/package/cross_deps_subset.sh
bash $R/tools/package/cross_deps_subset.sh
export PKG_CONFIG_LIBDIR=/prefix/lib/pkgconfig PKG_CONFIG_PATH=
echo "=== FFmpeg for Windows: $(pkg-config --modversion libavcodec) (libavcodec)"
echo "=== decoder check (cross-compiled, run under Wine)"
x86_64-w64-mingw32-gcc -O1 -static -o /work/decode_check.exe /avs/wincross/decode_check.c $(pkg-config --cflags libavformat libavcodec) $(pkg-config --static --libs libavformat libavcodec)
WINE=$(command -v wine64 || command -v wine || echo /usr/lib/wine/wine64)   # Ubuntu's wine64 package has no /usr/bin wrapper
if [ -f /avs/samples/recording.ts ]; then   # an AVS+ transport stream recorded with OnAir, if there is one
  "$WINE" /work/decode_check.exe 'Z:\avs\samples\recording.ts' 2>&1 | grep -v -E "Packet corrupt|PES packet|Header missing|corrupt input"
else
  "$WINE" /work/decode_check.exe 2>&1 | head -1; echo "(no samples/recording.ts: the decoder is listed but nothing is decoded)"
fi
echo "=== OnAir for Windows"
cmake -S /src -B /work/onair-build "-DCMAKE_TOOLCHAIN_FILE=/src/packaging/windows/mingw-toolchain.cmake" -DCMAKE_BUILD_TYPE=Release \
  -DDECT2_BUILD_APP=ON -DDECT2_BUILD_TESTS=ON -DDECT2_HAVE_HAMLIB=OFF -DDECT2_WITH_SOAPY=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 > /work/cmake-configure.log 2>&1 || { tail -30 /work/cmake-configure.log; exit 1; }
cmake --build /work/onair-build -j"$(nproc)" --target dect2 dect2cli test_ts 2>&1 | grep -E "error|Error|Built target" | head -40
ls -la /work/onair-build/dect2.exe /work/onair-build/dect2cli.exe /work/onair-build/test_ts.exe
file /work/onair-build/dect2.exe
echo "=== test_ts.exe under Wine"
cd /work/onair-build && "$WINE" ./test_ts.exe 2>&1 | tail -3
echo "=== strings"
grep -c "Guangdian profile)" /work/onair-build/dect2.exe
