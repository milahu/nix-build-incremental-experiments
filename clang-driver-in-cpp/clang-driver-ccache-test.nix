/*
nix-build -E 'with import <nixpkgs> { }; callPackage ./clang-driver-ccache-test.nix { }'
*/

/*
docs
C/C++ infrastructure in nixpkgs
how the compilers/linkers are integrated into stdenv
how the build system abstraction works
https://discourse.nixos.org/t/nix-friday-streaming-about-nix-every-friday/4655/84

*/

/*
nix-build -E 'with import <nixpkgs> { }; callPackage ./clang-driver-ccache-test.nix { }'
*/

{ lib
, stdenv
, recurseIntoAttrs
, callPackage
, overrideCC
, stdenvAdapters
, gcc7Stdenv
, buildPackages
, targetPackages
, llvmPackages_13
, cmake
, pkgs
}:

let
  llvm-stdenv-ccache = llvm-stdenv-ccache-old; # clang is patched, but throws link errors
  /*
    /nix/store/21cjydqip7n3yw5qbpf7y67m2mchkq4f-clang-driver-ccache-wrapper-2021-09-29/bin/clang CMakeFiles/cmTC_f8dc0.dir/testCCompiler.c.o -o cmTC_f8dc0 
    clang-driver-ccache: hello llvm::errs
    clang-driver-ccache: hello llvm::dbgs
    ld: error: cannot open crtbegin.o: No such file or directory
    ld: error: unable to find library -lgcc
    ld: error: unable to find library -lgcc
    ld: error: cannot open crtend.o: No such file or directory
    clang-driver-ccache-13.0: error: linker command failed with exit code 1 (use -v to see invocation)
    clang-driver-ccache: hello llvm::outs
  */
  #llvm-stdenv-ccache = llvm-stdenv-ccache-new; # clang is not patched



  # broken
  # based on nixpkgs/pkgs/top-level/all-packages.nix
  llvmPackages_13-ccache = recurseIntoAttrs (callPackage ./llvm-13-ccache.nix ({
    inherit (stdenvAdapters) overrideCC;
    # TODO(milahu) buildLlvmTools? targetLlvmLibraries?
    # FIXME(milahu) buildPackages has wrong clang
    # TODO build == host == target ?
    buildLlvmTools = buildPackages.llvmPackages_13.tools; 
    targetLlvmLibraries = targetPackages.llvmPackages_13.libraries or llvmPackages_13.libraries;
  } // lib.optionalAttrs (stdenv.hostPlatform.isi686 && buildPackages.stdenv.cc.isGNU) {
    stdenv = gcc7Stdenv;
  }));

  llvm-stdenv-ccache-new = llvmPackages_13-ccache.stdenv;



  # old:

  llvmPackages = pkgs.llvmPackages_13;

  clang-driver-ccache = pkgs.callPackage ./clang-driver-ccache.nix { };

  /* output is not allowed to refer to the following paths: ... llvm ...
  llvm-stdenv-ccache = pkgs.stdenv.override {
    #cc = gcc-unwrapped;
    cc = clang-driver-ccache;
  };
  */

  /*
  llvm-packages-ccache = llvmPackages.overrideAttrs {
    clang-unwrapped = clang-driver-ccache;
  };
  */

  #llvm-stdenv-ccache = pkgs.overrideCC llvmPackages.stdenv clang-driver-ccache; # no bin/ld

  /* error: attribute 'mkDerivation' missing
  llvm-stdenv-ccache = pkgs.symlinkJoin {
    name = "llvm-stdenv-ccache";
    paths = [
      llvmPackages.stdenv
      clang-driver-ccache
    ];
  };
  */

  /* https://discourse.nixos.org/t/use-clang-without-gccs-c-standard-library/9884/4

    (clangStdenv.override (x: {
      cc = x.cc.override (_: {
        libcxx = llvmPackages.libcxx;
      });
    })).mkDerivation {

  */



  /*
  # TODO test
  llvmPackages-ccache = llvmPackages.override (a: {
    tools = a.tools.override (b: {
      clang-unwrapped = clang-driver-ccache;
    });
  });
  llvm-stdenv-ccache = llvmPackages-ccache.stdenv;
  */




  bintools' = tools.bintools;

  tools = llvmPackages.tools.overrideAttrs {
    clang-unwrapped = clang-driver-ccache;
  };

  release_version = "13.0.0";

  mkExtraBuildCommands0 = cc: ''
    rsrc="$out/resource-root"
    mkdir "$rsrc"
    ln -s "${cc.lib}/lib/clang/${release_version}/include" "$rsrc"
    echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags
  '';
  mkExtraBuildCommands = cc: mkExtraBuildCommands0 cc + ''
    ln -s "${targetLlvmLibraries.compiler-rt.out}/lib" "$rsrc/lib"
    ln -s "${targetLlvmLibraries.compiler-rt.out}/share" "$rsrc/share"
  '';

  targetLlvmLibraries = llvmPackages;

  clangNoLibcxx = pkgs.wrapCCWith rec {
    #cc = tools.clang-unwrapped;
    #cc = clang-driver-ccache;
    cc = tools.clang-unwrapped;
    libcxx = null;
    bintools = bintools';
    extraPackages = [
      targetLlvmLibraries.compiler-rt
    ];
    extraBuildCommands = ''
      echo "-rtlib=compiler-rt" >> $out/nix-support/cc-cflags
      echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
      echo "-nostdlib++" >> $out/nix-support/cc-cflags
    '' + mkExtraBuildCommands cc;
  };



  # old
  # https://github.com/NixOS/nixpkgs/issues/129595
  #llvm-stdenv-ccache = pkgs.overrideCC llvmPackages.stdenv (
  llvm-stdenv-ccache-old = pkgs.overrideCC pkgs.stdenv (
    pkgs.wrapCCWith rec {
      cc = clang-driver-ccache;
      #libc = xxx; # TODO glibc / musl

      libcxx = llvmPackages.libcxx;
      /*
      libcxx = llvmPackages.libcxx.overrideAttrs {
        stdenv = pkgs.overrideCC pkgs.stdenv llvmPackages.clangNoLibcxx;
        # error: attempt to call something which is not a function but a set
      };
      */

      #bintools = llvmPackages.bintools-unwrapped;

      # https://github.com/NixOS/nixpkgs/issues/129595
      #libc = pkgs.musl;
      libc = pkgs.glibc; # fixme? ld: error: cannot open crtbegin.o: No such file
      #libc = null;
      # note: binutils == bintools?
      # binutils: binutils-2.35.2/bin/ld: cannot find crt1.o: No such file
      #binutils = llvmPackages.binutils; # x called with unexpected argument 'binutils'
      bintools = pkgs.wrapBintoolsWith {
        #bintools = llvmPackages.bintools-unwrapped;
        bintools = llvmPackages.tools.bintools;
        # FIXME
        #     is: /nix/store/sp21yj3n9d58pg15glzrwhkhrcw6kg7w-binutils-2.35.2/bin/ld
        # should: /nix/store/cy3hlnm4l3yplbi7aszjvpz26ky1cp46-llvm-binutils-13.0.0/bin/ld
        #libc = null;
        #libc = pkgs.musl;
        libc = pkgs.glibc; # fixme? ld: error: cannot open crtbegin.o: No such file
      };
      extraPackages = [
        llvmPackages.libcxxabi
        llvmPackages.compiler-rt
        llvmPackages.libunwind
        #pkgs.glibc
        #llvmPackages.libcxx
      ];

      #bintools = llvmPackages.tools.bintools;

      /* FIXME bintools
        $ nix-build -E 'with import <nixpkgs> { }; callPackage ./clang-driver-ccache-test.nix { }'
        /nix/store/vjzj56c86jyncfz6hl4riakj4g833r33-clang-driver-ccache-wrapper-2021-09-29/bin/clang CMakeFiles/cmTC_335d4.dir/testCCompiler.c.o -o cmTC_335d4
        ld: error: cannot open crtbegin.o: No such file or directory # gcc
        ld: error: unable to find library -lc++abi # libcxxabi / llvmPackages_13.libcxxabi
        ld: error: unable to find library -lgcc # -> glibc: lib/libgcc_s.so
        ld: error: cannot open crtend.o: No such file or directory # gcc
        clang-driver-ccache-13.0: error: linker command failed with exit code 1 (use -v to see invocation)

        $ /nix/store/l3rspll9vjk3bcphyx46xwcchz74xyml-clang-driver-ccache-2021-09-29/bin/clang++ clang-driver-ccache-test/test.cc 
        /nix/store/sp21yj3n9d58pg15glzrwhkhrcw6kg7w-binutils-2.35.2/bin/ld: cannot find crt1.o: No such file or directory # glibc / musl
        /nix/store/sp21yj3n9d58pg15glzrwhkhrcw6kg7w-binutils-2.35.2/bin/ld: cannot find crti.o: No such file or directory # glibc / musl
        /nix/store/sp21yj3n9d58pg15glzrwhkhrcw6kg7w-binutils-2.35.2/bin/ld: cannot find crtbegin.o: No such file or directory # gcc
        /nix/store/sp21yj3n9d58pg15glzrwhkhrcw6kg7w-binutils-2.35.2/bin/ld: cannot find -lstdc++ # gcc-unwrapped.lib -> lib/libstdc++.so
        clang-driver-ccache-13.0: error: linker command failed with exit code 1 (use -v to see invocation)

        https://stackoverflow.com/questions/6329887/compiling-problems-cannot-find-crt1-o
        https://stackoverflow.com/questions/3299511/missing-crt1-and-crti-when-crosscompiling

        $ grep add-flags /nix/store/vjzj56c86jyncfz6hl4riakj4g833r33-clang-driver-ccache-wrapper-2021-09-29/bin/clang
        source /nix/store/f78lvyxcii6s7xqxxnbd8a5mwhcwsa4x-llvm-binutils-wrapper-13.0.0/nix-support/add-flags.sh
        source /nix/store/vjzj56c86jyncfz6hl4riakj4g833r33-clang-driver-ccache-wrapper-2021-09-29/nix-support/add-flags.sh

        $ grep add-flags /nix/store/vjzj56c86jyncfz6hl4riakj4g833r33-clang-driver-ccache-wrapper-2021-09-29/bin/ld
        source /nix/store/f78lvyxcii6s7xqxxnbd8a5mwhcwsa4x-llvm-binutils-wrapper-13.0.0/nix-support/add-flags.sh

        $ grep ldflags /nix/store/f78lvyxcii6s7xqxxnbd8a5mwhcwsa4x-llvm-binutils-wrapper-13.0.0/nix-support/add-flags.sh
        NIX_LDFLAGS_x86_64_unknown_linux_gnu+=" $(< /nix/store/f78lvyxcii6s7xqxxnbd8a5mwhcwsa4x-llvm-binutils-wrapper-13.0.0/nix-support/libc-ldflags)"

        $ cat /nix/store/f78lvyxcii6s7xqxxnbd8a5mwhcwsa4x-llvm-binutils-wrapper-13.0.0/nix-support/libc-ldflags
        -L/nix/store/ff88p8pnhdmf8bflzbxldys21djw9dp0-glibc-2.33-56/lib

        $ ls /nix/store/vjzj56c86jyncfz6hl4riakj4g833r33-clang-driver-ccache-wrapper-2021-09-29/nix-support/ | grep ldflags
        cc-ldflags
        libc-ldflags
        libcxx-ldflags

        $ cat /nix/store/vjzj56c86jyncfz6hl4riakj4g833r33-clang-driver-ccache-wrapper-2021-09-29/nix-support/cc-ldflags
        -L/nix/store/l3rspll9vjk3bcphyx46xwcchz74xyml-clang-driver-ccache-2021-09-29/lib

        $ ls /nix/store/l3rspll9vjk3bcphyx46xwcchz74xyml-clang-driver-ccache-2021-09-29/lib
        No such file
      */
      #libc = pkgs.musl;
      #libc = llvmPackages.tools.bintools.libc;
      /*
      bintools = pkgs.binutils.override {
        libc = pkgs.musl;
      };
      */
      #extraBuildCommands = pkgs.mkExtraBuildCommands cc; # nixpkgs/pkgs/development/compilers/llvm/13/default.nix
    }
  );

  /*
    # nixpkgs/pkgs/development/compilers/llvm/13/default.nix
    #stdenv = overrideCC stdenv buildLlvmTools.clang;

    # buildLlvmTools = tools, but from the previous stage, for cross
    buildLlvmTools = llvmPackages;

    # targetLlvmLibraries = libraries, but from the next stage, for cross
    targetLlvmLibraries = llvmPackages;

    # pick clang appropriate for package set we are targeting
    clang = clangUseLLVM;

    bintools' = tools.bintools;

    tools = llvmPackages.tools; # todo?

    clangUseLLVM = wrapCCWith rec {
      #cc = tools.clang-unwrapped;
      cc = clang-driver-ccache;
      libcxx = targetLlvmLibraries.libcxx;
      bintools = bintools';
      extraPackages = [
        targetLlvmLibraries.libcxxabi
        targetLlvmLibraries.compiler-rt
      ] ++ lib.optionals (!stdenv.targetPlatform.isWasm) [
        targetLlvmLibraries.libunwind
      ];
      extraBuildCommands = ''
        echo "-rtlib=compiler-rt -Wno-unused-command-line-argument" >> $out/nix-support/cc-cflags
        echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
      '' + lib.optionalString (!stdenv.targetPlatform.isWasm) ''
        echo "--unwindlib=libunwind" >> $out/nix-support/cc-cflags
      '' + lib.optionalString (!stdenv.targetPlatform.isWasm && stdenv.targetPlatform.useLLVM or false) ''
        echo "-lunwind" >> $out/nix-support/cc-ldflags
      '' + lib.optionalString stdenv.targetPlatform.isWasm ''
        echo "-fno-exceptions" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands cc;
    };


    libcxxClang = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = targetLlvmLibraries.libcxx;
      extraPackages = [
        targetLlvmLibraries.libcxxabi
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = mkExtraBuildCommands cc;
    };


  */
in

llvm-stdenv-ccache.mkDerivation {
  pname = "clang-driver-ccache-test";
  version = "0.0.1";
  src = ./src/clang-driver-ccache-test;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ pkgs.which ];

  # FIXME this is the wrong clang
  # clang = /nix/store/dwc062alcf1pvdv8dvgwfh9xdl8v2400-clang-wrapper-13.0.0/bin/clang
  postBuild = ''
    echo clang = $(which clang) = $(readlink -f $(which clang))
  '';
  #  echo force rebuild
}
