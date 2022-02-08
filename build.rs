// https://github.com/google/autocxx

// TODO call clang-config to get include path

fn main() {
  let path1 = std::path::PathBuf::from(std::env::var("CLANG_INCLUDE").unwrap());
  let path2 = std::path::PathBuf::from(std::env::var("LLVM_INCLUDE").unwrap());
  let path3 = std::path::PathBuf::from(std::env::var("LIBCXX_INCLUDE").unwrap());
  let path4 = std::path::PathBuf::from(std::env::var("LIBC_INCLUDE").unwrap());
  let path5 = std::path::PathBuf::from(std::env::var("CLANG_INCLUDE_2").unwrap());

  let mut b = autocxx_build::Builder::new("src/main.rs", &[&path1, &path2, &path3, &path4, &path5]).expect_build();
  // This assumes all your C++ bindings are in main.rs
  b.flag_if_supported("-std=c++14").compile("autocxx-clang");
  println!("cargo:rerun-if-changed=src/main.rs");

  // Add instructions to link to any C++ libraries you need.
}
