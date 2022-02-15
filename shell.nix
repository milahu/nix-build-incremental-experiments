/*
nix-shell /home/user/src/nixos/nix-ccache/nix-build-incremental/nix-build-incremental-experiments/shell.nix
*/

{ pkgs ? import <nixpkgs> {} }:

let
  llvmPackages = pkgs.llvmPackages_13; # 13 = latest llvm in nixpkgs
  #llvmPackages = pkgs.llvmPackages_10;
  #llvmPackages = pkgs.llvmPackages_5; # 5 = oldest llvm in nixpkgs
  # https://github.com/KyleMayes/clang-rs requires clang <= 10

  rust-autocxx-reduce = pkgs.callPackage ./rust-autocxx-reduce.nix { };
in

pkgs.mkShell rec {
  CLANG_INCLUDE = "${llvmPackages.clang-unwrapped.dev}/include";
  # /nix/store/x5s3qmy7pnwyk7n7ypr556ns92jrxkkz-clang-10.0.1-dev/include

  CLANG_INCLUDE_2 = "${llvmPackages.clang-unwrapped.lib}/lib/clang/10.0.1/include";
  # /nix/store/qjvrbibnrh1hdba5f68kwa4wa7nbvhyq-clang-10.0.1-lib/lib/clang/10.0.1/include

  LLVM_INCLUDE = "${llvmPackages.llvm.dev}/include";
  # /nix/store/mck6a026qp4ydzkz9wn6ww2npnjmidlx-llvm-10.0.1-dev/include

  LIBCXX_INCLUDE = "${llvmPackages.libcxx.dev}/include/c++/v1";
  # /nix/store/hhz475mhdma8psfv1m8fa8fvmv5dv370-libcxx-10.0.1-dev/include/c++/v1

  LIBC_INCLUDE = "${pkgs.glibc.dev}/include";
  # /nix/store/i9nqsplgfxfx5c1aa2v1hml7lla1r3s8-glibc-2.33-56-dev/include

  /*
  # needed for https://github.com/google/autocxx/tree/main/tools/reduce
  #CXXFLAGS = "-isystem ${LIBC_INCLUDE} -isystem ${LIBCXX_INCLUDE} -isystem ${LIBCXX_INCLUDE}";

  CXXFLAGS = pkgs.lib.concatStringsSep " -isystem " [
    "/nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0"
    "/nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0/x86_64-unknown-linux-gnu"
    "/nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0/backward"
    "/nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/lib/gcc/x86_64-unknown-linux-gnu/10.3.0/include"
    "/nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include"
    "/nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/lib/gcc/x86_64-unknown-linux-gnu/10.3.0/include-fixed"
    LIBCXX_INCLUDE
    LIBC_INCLUDE # "/nix/store/i9nqsplgfxfx5c1aa2v1hml7lla1r3s8-glibc-2.33-56-dev/include"
  ];
  */
  /*
    nix-shell -p gcc
    gcc -v -E -x c++ - </dev/null 2>&1 | grep -A999 -F '#include <...> search starts here:'
    /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0
    /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0/x86_64-unknown-linux-gnu
    /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0/backward
    /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/lib/gcc/x86_64-unknown-linux-gnu/10.3.0/include
    /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include
    /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/lib/gcc/x86_64-unknown-linux-gnu/10.3.0/include-fixed
    /nix/store/i9nqsplgfxfx5c1aa2v1hml7lla1r3s8-glibc-2.33-56-dev/include
  */

  # debug
  shellHook = ''
    echo LLVM_INCLUDE = $LLVM_INCLUDE
    echo CLANG_INCLUDE = $CLANG_INCLUDE
    echo CLANG_INCLUDE_2 = $CLANG_INCLUDE_2
    echo LIBC_INCLUDE = $LIBC_INCLUDE
    echo LIBCXX_INCLUDE = $LIBCXX_INCLUDE
    echo LIBCLANG_PATH = $LIBCLANG_PATH
    echo CLANG_INCLUDE_PATH:
    echo $CLANG_INCLUDE_PATH | tr ':' '\n'
  '';

  CLANG_INCLUDE_PATH = pkgs.lib.concatStringsSep ":" [
    # clang internal include paths
    # missing in llvm 5: "${llvmPackages.compiler-rt-libc.dev}/include" # /nix/store/074p8pxyzwa7vim21ivhcsg5az9c9g91-compiler-rt-libc-13.0.0-dev/include
    /*
    "${pkgs.gcc-unwrapped}/include/c++/10.3.0" # /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0
    "${pkgs.gcc-unwrapped}/include/c++/10.3.0/x86_64-unknown-linux-gnu" # /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0/x86_64-unknown-linux-gnu
    "${pkgs.gcc-unwrapped}/include/c++/10.3.0/backward" # /nix/store/a87yinndp3fgpxxfxb9fyr9aln5yzsr7-gcc-10.3.0/include/c++/10.3.0/backward
    breaks with clang:
    #  /nix/store/c4yv7mgfxj45yvibl6q4xq0747cj1h6s-clang-wrapper-10.0.1/resource-root/include/stddef.h:18:19:
    # error: missing binary operator before token "("
    # 18 | #if !__has_feature(modules)
    #    |                   ^
    */
    LIBCXX_INCLUDE # /nix/store/hhz475mhdma8psfv1m8fa8fvmv5dv370-libcxx-10.0.1-dev/include/c++/v1
    "${llvmPackages.clang}/resource-root/include" # /nix/store/dwc062alcf1pvdv8dvgwfh9xdl8v2400-clang-wrapper-13.0.0/resource-root/include

    #"${pkgs.glibc.dev}/include" # /nix/store/i9nqsplgfxfx5c1aa2v1hml7lla1r3s8-glibc-2.33-56-dev/include
    # glibc: error: use of undeclared identifier '__builtin_va_arg_pack'
    "${pkgs.musl.dev}/include" # /nix/store/rbxa3lrppsbdca5pdm7g3ysgri59l4kz-musl-1.2.2-dev/include/features.h
    #"${pkgs.uclibc}/include" # /nix/store/9xzvyx7p3yjclq2qkyggim42yvzsirdf-uclibc-ng-1.0.38/include/features.h

    # llvm + clang
    LLVM_INCLUDE
    CLANG_INCLUDE
    CLANG_INCLUDE_2
  ];

  LIBCLANG_PATH = "${llvmPackages.clang-unwrapped.lib}/lib"; # libclang.so # fix: Unable to find libclang

  buildInputs = with pkgs; [
    cargo
    rustc
    rustfmt
    llvmPackages.clang-unwrapped
    llvmPackages.clang-unwrapped.dev
    llvmPackages.clang-unwrapped.lib # lib/libclang.so lib/clang/10.0.1/include/stddef.h
    llvmPackages.llvm.dev
    llvmPackages.llvm # bin/llvm-config
    glibc.dev # include/features.h
    llvmPackages.libcxx.dev # include/c++/v1/new

    #gcc # g++ is needed for https://github.com/google/autocxx/tree/main/tools/reduce

    #rust-autocxx-reduce
    creduce

    halfempty # faster than creduce?
  ];
}
