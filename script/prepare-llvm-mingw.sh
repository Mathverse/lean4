#!/usr/bin/env bash
set -euo pipefail

# run from root build directory in clang64 shell (NOT mingw64) as in
# ```
# eval cmake ../.. $(../../script/prepare-llvm-mingw.sh ~/Downloads/lean-llvm-x86_64-w64-windows-gnu.tar.zst)
# ```

# use full LLVM release for compiling C++ code, but subset for compiling C code and distribution

# must run `tar` twice in case of symlinked files listed before their targets...
[[ -d llvm ]] || (mkdir llvm; tar xf $1 --dereference --strip-components 1 --directory llvm || tar xf $1 --dereference --strip-components 1 --directory llvm)
mkdir -p stage1/{bin,lib,include/clang}
# a C compiler!
cp llvm/bin/clang stage1/bin/
# a linker!
cp llvm/bin/{ld.lld,lld} stage1/bin/
# a static archiver!
cp llvm/bin/llvm-ar stage1/bin/
# dependencies of the above
cp $(ldd llvm/bin/{clang,lld,llvm-ar}.exe | cut -f3 -d' ' --only-delimited | grep -E 'llvm|clang64') stage1/bin
# lean.h dependencies
cp llvm/lib/clang/*/include/{std*,__std*,limits}.h stage1/include/clang
# single Windows dependency
echo '
// https://docs.microsoft.com/en-us/windows/win32/api/errhandlingapi/nf-errhandlingapi-seterrormode
#define SEM_FAILCRITICALERRORS 0x0001
__declspec(dllimport) __stdcall unsigned int SetErrorMode(unsigned int uMode);' > stage1/include/clang/windows.h
# COFF dependencies
cp /clang64/x86_64-w64-mingw32/lib/{crtbegin,crtend,crt2,dllcrt2}.o stage1/lib/
# runtime
(cd llvm; cp --parents lib/clang/*/lib/*/libclang_rt.builtins* ../stage1)
# further dependencies
cp /clang64/x86_64-w64-mingw32/lib/lib{m,bcrypt,mingw32,moldname,mingwex,msvcrt,pthread,advapi32,shell32,user32,kernel32,ucrtbase}.* /clang64/lib/libgmp.a llvm/lib/lib{c++,c++abi,unwind}.a stage1/lib/
echo -n " -DLEAN_STANDALONE=ON"
echo -n " -DCMAKE_C_COMPILER=$PWD/stage1/bin/clang.exe -DCMAKE_CXX_COMPILER=$PWD/llvm/bin/clang++.exe -DLEAN_CXX_STDLIB='-lc++ -lc++abi'"
echo -n " -DSTAGE0_CMAKE_C_COMPILER=clang -DSTAGE0_CMAKE_CXX_COMPILER=clang++"
# allow C++ code to include /usr since it needs quite a few more headers
# allow C++ code to include /usr since it needs quite a few more headers
# set sysroot for both C++ and C to make sure we have all necessary runtime files, but don't embed in `leanc` so users can still link to system libs
echo -n " -DLEAN_EXTRA_CXX_FLAGS='--sysroot $PWD/llvm -I/clang64/include/ -I/clang64/x86_64-w64-mingw32/include/'"
echo -n " -DLEANC_INTERNAL_FLAGS='-I ROOT/include/clang' -DLEANC_OPTS='--sysroot $PWD/stage1' -DLEANC_CC=ROOT/bin/clang.exe"
echo -n " -DLEANC_INTERNAL_LINKER_FLAGS='-L ROOT/lib -static-libgcc -Wl,-Bstatic -lgmp -lunwind -Wl,-Bdynamic -lucrtbase -fuse-ld=lld'"
# do not set `LEAN_CC` for tests
echo -n " -DAUTO_THREAD_FINALIZATION=OFF -DSTAGE0_AUTO_THREAD_FINALIZATION=OFF"
echo -n " -DLEAN_TEST_VARS=''"
