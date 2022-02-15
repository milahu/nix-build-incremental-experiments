// https://github.com/google/autocxx

// TODO call clang-config to get include path

// use the "wrapped" clang to get the system include paths:
//   nix-shell -p clang_13
//   clang -v -E -x c++ - </dev/null 2>&1 | grep -A999 -F '#include <...> search starts here:'

fn main() {
  let path_list_str = std::env::var("CLANG_INCLUDE_PATH").unwrap();
  let path_list = path_list_str.split(":").collect::<Vec<&str>>();
  // debug
  for path in &path_list {
    println!("build.rs: path = {}", path);
  }

  let mut b = autocxx_build::Builder::new("src/main.rs", &path_list).expect_build();
  // This assumes all your C++ bindings are in main.rs
  b.flag_if_supported("-std=c++14").compile("autocxx-clang");
  println!("cargo:rerun-if-changed=src/main.rs");

  // Add instructions to link to any C++ libraries you need.
}
