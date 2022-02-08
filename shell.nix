{ pkgs ? import <nixpkgs> {} }:

let
  #llvmPackages = pkgs.llvmPackages_13;
  llvmPackages = pkgs.llvmPackages_10;
  # https://github.com/KyleMayes/clang-rs requires clang <= 10
in

pkgs.mkShell {
  CLANG_INCLUDE = "${llvmPackages.clang-unwrapped.dev}/include";
  CLANG_INCLUDE_2 = "${llvmPackages.clang-unwrapped.lib}/lib/clang/10.0.1/include";
  LLVM_INCLUDE = "${llvmPackages.llvm.dev}/include";
  LIBCXX_INCLUDE = "${llvmPackages.libcxx.dev}/include/c++/v1";
  LIBC_INCLUDE = "${pkgs.glibc.dev}/include";

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
    pkgs.glibc.dev # include/features.h
    llvmPackages.libcxx.dev # include/c++/v1/new
  ];
}
