# based on nixpkgs/pkgs/development/compilers/llvm/13/default.nix

{ lowPrio, newScope, pkgs, lib, stdenv, cmake
, gccForLibs, preLibcCrossHeaders
, libxml2, python3, isl, fetchFromGitHub, overrideCC, wrapCCWith, wrapBintoolsWith

, buildLlvmTools # tools, but from the previous stage, for cross
# nixpkgs/pkgs/top-level/all-packages.nix
#   buildLlvmTools = buildPackages.llvmPackages_13.tools

, targetLlvmLibraries # libraries, but from the next stage, for cross
# nixpkgs/pkgs/top-level/all-packages.nix
#   targetLlvmLibraries = targetPackages.llvmPackages_13.libraries or llvmPackages_13.libraries;

# This is the default binutils, but with *this* version of LLD rather
# than the default LLVM verion's, if LLD is the choice. We use these for
# the `useLLVM` bootstrapping below.
, bootBintoolsNoLibc ?
    if stdenv.targetPlatform.linker == "lld"
    then null
    else pkgs.bintoolsNoLibc
, bootBintools ?
    if stdenv.targetPlatform.linker == "lld"
    then null
    else pkgs.bintools
, darwin
, symlinkJoin
}:

let
  release_version = "13.0.0";
  candidate = ""; # empty or "rcN"
  dash-candidate = lib.optionalString (candidate != "") "-${candidate}";
  rev = ""; # When using a Git commit
  rev-version = ""; # When using a Git commit
  version = if rev != "" then rev-version else "${release_version}${dash-candidate}";
  targetConfig = stdenv.targetPlatform.config;

  src = fetchFromGitHub {
    owner = "llvm";
    repo = "llvm-project";
    rev = if rev != "" then rev else "llvmorg-${version}";
    sha256 = "0cjl0vssi4y2g4nfr710fb6cdhxmn5r0vis15sf088zsc5zydfhw";
  };

  llvm_meta = {
    license     = lib.licenses.ncsa;
    maintainers = with lib.maintainers; [ lovek323 raskin dtzWill primeos ];
    platforms   = lib.platforms.all;
  };

  #buildLlvmTools = tools; # TODO(milahu) test
  # circle?? buildLlvmTools -> tools -> buildLlvmTools -> tools

  tools = lib.makeExtensible (tools: let
    callPackage = newScope (tools // { inherit stdenv cmake libxml2 python3 isl release_version version src buildLlvmTools; });
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

  bintoolsNoLibc' =
    if bootBintoolsNoLibc == null
    then tools.bintoolsNoLibc
    else bootBintoolsNoLibc;
  bintools' =
    if bootBintools == null
    then tools.bintools
    else bootBintools;

  in rec {



    #libllvm = callPackage ./llvm {
    libllvm = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/llvm> {
      inherit llvm_meta;
    };

    # `llvm` historically had the binaries.  When choosing an output explicitly,
    # we need to reintroduce `outputSpecified` to get the expected behavior e.g. of lib.get*
    llvm = tools.libllvm.out // { outputSpecified = false; };

    #libclang = callPackage ./clang {
    libclang-old = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/clang> {
      inherit llvm_meta;
    };

    # build new clang driver
    clang-driver-ccache = pkgs.callPackage ./clang-driver-ccache.nix { };

    # patch clang driver in existing libclang derivation
    # patch large derivation without recompile
    # https://stackoverflow.com/questions/41465738/override-scripts-in-nix-derivations
    libclang = stdenv.mkDerivation {
      inherit (libclang-old) pname version outputs propagatedBuildInputs;
      src = libclang-old;
      buildPhase = ''
        (
          set -x

          echo "libclang buildPhase: outputs = $outputs"

          cp -ra ${libclang-old.out} $out
          cp -ra ${libclang-old.lib} $lib
          cp -ra ${libclang-old.dev} $dev
          cp -ra ${libclang-old.python} $python

          chmod -R +w $out
          chmod -R +w $lib
          chmod -R +w $dev
          chmod -R +w $python

          mv $out/bin/clang-13 $out/bin/clang-13-no-ccache
          cp $(readlink -f ${clang-driver-ccache}/bin/clang) $out/bin/clang-13

          # patch paths
          #find $out $lib $dev $python -type f -print0 | xargs -0 perl

          echo patch output paths ...
          find $out $lib $dev $python -type f -print0 | xargs -0 sed -i "s,${libclang-old.out},$out,g; s,${libclang-old.lib},$lib,g; s,${libclang-old.dev},$dev,g; s,${libclang-old.python},$python,g"
          echo patch output paths done
        )
      '';
      #    find $out $lib $dev $python -type f -print0 | xargs -0 grep -F -e ${libclang-old.out} -e ${libclang-old.lib} -e ${libclang-old.dev} -e ${libclang-old.python} || echo ok
      dontInstall = true;
    };

    # tools.libclang -> libclang
    #clang-unwrapped = tools.libclang.out // { outputSpecified = false; };
    clang-unwrapped = libclang.out // { outputSpecified = false; };

    #clang-unwrapped = clang-driver-ccache;
    # FIXME cc.lib -> attribute 'lib' missing
    # cc == clang-unwrapped

    llvm-manpages = lowPrio (tools.libllvm.override {
      enableManpages = true;
      python3 = pkgs.python3;  # don't use python-boot
    });

    clang-manpages = lowPrio (tools.libclang.override {
      enableManpages = true;
      python3 = pkgs.python3;  # don't use python-boot
    });

    # TODO: lldb/docs/index.rst:155:toctree contains reference to nonexisting document 'design/structureddataplugins'
    # lldb-manpages = lowPrio (tools.lldb.override {
    #   enableManpages = true;
    #   python3 = pkgs.python3;  # don't use python-boot
    # });

    # pick clang appropriate for package set we are targeting
    clang =
      /**/ if stdenv.targetPlatform.useLLVM or false then tools.clangUseLLVM
      else if (pkgs.targetPackages.stdenv or stdenv).cc.isGNU then tools.libstdcxxClang
      else tools.libcxxClang;

    libstdcxxClang = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      # libstdcxx is taken from gcc in an ad-hoc way in cc-wrapper.
      libcxx = null;
      extraPackages = [
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = mkExtraBuildCommands cc;
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

    #lld = callPackage ./lld {
    lld = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/lld> {
      inherit llvm_meta;
    };

    #lldb = callPackage ./lldb {
    lldb = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/lldb> {
      inherit llvm_meta;
      inherit (darwin) libobjc bootstrap_cmds;
      inherit (darwin.apple_sdk.libs) xpc;
      inherit (darwin.apple_sdk.frameworks) Foundation Carbon Cocoa;
    };

    # Below, is the LLVM bootstrapping logic. It handles building a
    # fully LLVM toolchain from scratch. No GCC toolchain should be
    # pulled in. As a consequence, it is very quick to build different
    # targets provided by LLVM and we can also build for what GCC
    # doesn’t support like LLVM. Probably we should move to some other
    # file.

    #bintools-unwrapped = callPackage ./bintools {};
    bintools-unwrapped = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/bintools> {};

    bintoolsNoLibc = wrapBintoolsWith {
      bintools = tools.bintools-unwrapped;
      libc = preLibcCrossHeaders;
    };

    bintools = wrapBintoolsWith {
      bintools = tools.bintools-unwrapped;
    };

    clangUseLLVM = wrapCCWith rec {
      cc = tools.clang-unwrapped;
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

    clangNoLibcxx = wrapCCWith rec {
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

    clangNoLibc = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = null;
      bintools = bintoolsNoLibc';
      extraPackages = [
        targetLlvmLibraries.compiler-rt
      ];
      extraBuildCommands = ''
        echo "-rtlib=compiler-rt" >> $out/nix-support/cc-cflags
        echo "-B${targetLlvmLibraries.compiler-rt}/lib" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands cc;
    };

    clangNoCompilerRt = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = null;
      bintools = bintoolsNoLibc';
      extraPackages = [ ];
      extraBuildCommands = ''
        echo "-nostartfiles" >> $out/nix-support/cc-cflags
      '' + mkExtraBuildCommands0 cc;
    };

    clangNoCompilerRtWithLibc = wrapCCWith rec {
      cc = tools.clang-unwrapped;
      libcxx = null;
      bintools = bintools';
      extraPackages = [ ];
      extraBuildCommands = mkExtraBuildCommands0 cc;
    };

  });

  #targetLlvmLibraries = libraries; # TODO milahu

  libraries = lib.makeExtensible (libraries: let
    callPackage = newScope (libraries // buildLlvmTools // { inherit stdenv cmake libxml2 python3 isl release_version version src; });
  in {

    #compiler-rt-libc = callPackage ./compiler-rt {
    compiler-rt-libc = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/compiler-rt> {
      inherit llvm_meta;
      stdenv = if stdenv.hostPlatform.useLLVM or false
               then overrideCC stdenv buildLlvmTools.clangNoCompilerRtWithLibc
               else stdenv;
    };

    #compiler-rt-no-libc = callPackage ./compiler-rt {
    compiler-rt-no-libc = callPackage <nixpkgs/pkgs/development/compilers/llvm/13/compiler-rt> {
      inherit llvm_meta;
      stdenv = if stdenv.hostPlatform.useLLVM or false
               then overrideCC stdenv buildLlvmTools.clangNoCompilerRt
               else stdenv;
    };

    # N.B. condition is safe because without useLLVM both are the same.
    compiler-rt = if stdenv.hostPlatform.isAndroid
      then libraries.compiler-rt-libc
      else libraries.compiler-rt-no-libc;

    stdenv = overrideCC stdenv buildLlvmTools.clang;

    libcxxStdenv = overrideCC stdenv buildLlvmTools.libcxxClang;

    libcxx = callPackage ./libcxx {
      inherit llvm_meta;
      stdenv = if stdenv.hostPlatform.useLLVM or false
               then overrideCC stdenv buildLlvmTools.clangNoLibcxx
               else (
                 # libcxx >= 13 does not build on gcc9
                 if stdenv.cc.isGNU && lib.versionOlder stdenv.cc.version "10"
                 then pkgs.gcc10Stdenv
                 else stdenv
               );
    };

    libcxxabi = let
      stdenv_ = if stdenv.hostPlatform.useLLVM or false
               then overrideCC stdenv buildLlvmTools.clangNoLibcxx
               else stdenv;
      cxx-headers = callPackage ./libcxx {
        inherit llvm_meta;
        stdenv = stdenv_;
        headersOnly = true;
      };
    in callPackage ./libcxxabi {
      stdenv = stdenv_;
      inherit llvm_meta cxx-headers;
    };

    libunwind = callPackage ./libunwind {
      inherit llvm_meta;
      stdenv = overrideCC stdenv buildLlvmTools.clangNoLibcxx;
    };

    openmp = callPackage ./openmp {
      inherit llvm_meta;
    };
  });

in { inherit tools libraries release_version; } // libraries // tools
