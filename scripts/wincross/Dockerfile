# Cross-compiles OnAir and its FFmpeg for Windows x64 with mingw-w64 (the posix-threads variant, for std::thread and winpthreads).
# Wine runs the cross-compiled test programs. Used as: docker run --rm -v <OnAir>:/src -v <prefix>:/prefix onair-wincross ...
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      g++-mingw-w64-x86-64-posix gcc-mingw-w64-x86-64-posix binutils-mingw-w64-x86-64 \
      gcc libc6-dev cmake make nasm pkg-config patch xz-utils bzip2 unzip zip curl ca-certificates git python3 file \
      wine64 \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix \
    && update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix
