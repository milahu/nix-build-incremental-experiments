/*
nix-build -E 'with import <nixpkgs> { }; callPackage ./clang-driver-ccache.nix { }'
*/

{ pkgs }:

let
  llvmPackages = pkgs.llvmPackages_13; # must be 13.0.0
in

llvmPackages.stdenv.mkDerivation rec {
  pname = "clang-driver-ccache";
  version = "2021-09-29";

  #propagatedBuildInputs = [
  buildInputs = [
    llvmPackages.llvm
    #llvmPackages.clang # bin
    llvmPackages.clang-unwrapped # include
    llvmPackages.libllvm # bin/llvm-config
  ];

  nativeBuildInputs = [
    pkgs.cmake
  ];

  cmakeFlags = [
    "-DCLANG_EXECUTABLE_VERSION=13.0.0"
  ];

  src = ./src/clang-driver-ccache;
  #dontUnpack = true;

  postInstall = ''
    for s in clang clang++ clang-cl clang-cpp; do
      ln -s -v ${pname} $out/bin/$s
    done
  '';

  # needed for autocxx-demo
  #LIBCLANG_PATH = "${llvmPackages.clang-unwrapped.lib}/lib"; # libclang.so # fix: Unable to find libclang
}
