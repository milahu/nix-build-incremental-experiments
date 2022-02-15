# nix build incremental experiments

* gcc or clang?
  * ~~gcc is a hard requirement for few projects, such as linux kernel~~
    * [compile linux kernel with clang](https://www.kernel.org/doc/html/latest/kbuild/llvm.html)
  * most projects should compile with clang
  * clang is easier to customize for our purpose
  * we want aggressive customization to reduce overhead (avoid double parsing)
    * so, "just another wrapper for gcc" is too slow
* transparent compiler patching
  * the decision "ccache or not" should be handled by nix, outside of nixpkgs
  * for example
    * when `bin/clang` is found in `buildInputs`
    * then nix will build a patched clang and use `bind mount` to provide the patched compiler under the requested storepath of the original compiler
* testing reproducibility
  * the compile-objects must be reproducible
  * to test reproducibility, we compile the same object multiple times, and compare the results
  * when at least two compiles were reproducibile, the object cache is used to load cache hits
  * the "at least two compiles" serve as "anecdotal evidence" that our "caching compiler driver" works
* https://github.com/rakhimov/cppdep
  * https://wiki.c2.com/?CppDependencyAnalysis
* llvm-clang
  * clang wrapper or clang plugin?
    * clang wrapper gives us more freedom/power.
    * probably [clang plugins](https://clang.llvm.org/docs/ClangPlugins.html) are too limited for our purpose
      * "Clang Plugins run FrontendActions over code"
  * clang preprocessor
    * https://clang.llvm.org/doxygen/classclang_1_1Preprocessor.html
    * https://stackoverflow.com/questions/13881506/retrieve-information-about-pre-processor-directives
  * https://clang.llvm.org/docs/ExternalClangExamples.html
    * cmake
      * https://stackoverflow.com/questions/55921707/setting-path-to-clang-library-in-cmake
    * C++
      * https://github.com/banach-space/clang-tutor clang plugins
      * https://github.com/llvm/llvm-project/tree/main/llvm/examples
      * https://github.com/patrykstefanski/dc-lang toy compiler, based on llvm, year 2019
      * https://github.com/Andersbakken/rtags/ indexer for c/c++, database of references, declarations, definitions, symbolnames
      * https://github.com/KDAB/codebrowser
      * https://github.com/rizsotto/Constantine toy project to learn how to write Clang plugin
      * https://doc.qt.io/qtcreator/creator-clang-codemodel.html static analysis, language server
      * https://github.com/lukhnos/refactorial refactoring C++ code, year 2013
    * python
      * https://github.com/mozilla/dxr indexer
      * https://github.com/axw/cmonster Python wrapper for the Clang C++ preprocessor and parser
  * https://clang.llvm.org/docs/LibTooling.html LibTooling is a library to support writing standalone tools based on Clang
  * [Using libclang to Parse C++](https://shaharmike.com/cpp/libclang/)
  * [C++ Static Analysis using Clang](https://ehsanakhgari.org/blog/2015-12-07/c-static-analysis-using-clang/)
  * [Data Dependence Graph (DDG)](https://llvm.org/docs/DependenceGraphs/index.html#data-dependence-graph) represents data dependencies between individual instructions.
  * https://clang.llvm.org/doxygen/classclang_1_1Preprocessor.html
  * clang-query: query the syntax tree of C source files
    * https://devblogs.microsoft.com/cppblog/exploring-clang-tooling-part-2-examining-the-clang-ast-with-clang-query/
    * https://firefox-source-docs.mozilla.org/code-quality/static-analysis/writing-new/clang-query.html
    * https://clang.llvm.org/docs/LibASTMatchersReference.html
* bazel
  * https://github.com/bazelbuild/bazel/blob/master/CODEBASE.md
  * https://github.com/bazelbuild/rules_cc
    * `-frandom-seed=xxxxxx` is normalized to `-frandom-seed=${output_file}` for reproducible builds
      * random-seed is rarely needed, to resolve collisions between symbol names
    * https://github.com/bazelbuild/rules_cc/blob/main/examples/test_cc_shared_library/foo.cc
      * where does bazel parse the `#include` commands?
      * call graph:
        * https://github.com/bazelbuild/rules_cc/blob/main/examples/test_cc_shared_library/BUILD
        * `deps = ["foo"]`
        * see `cc_library(name = "foo"` -> all `#include` commands are declared in the `BUILD` file
        * -> bazel does NOT parse `#include` commands from C source files
  * https://docs.bazel.build/versions/main/build-ref.html#dependencies
    * Declared dependencies = all the inputs provided by nix
    * Actual dependencies = the subset of inputs used for compiling
    * "For correct builds, the graph of actual dependencies A must be a subgraph of the graph of declared dependencies D."
  * https://docs.bazel.build/versions/main/skylark/performance.html
    * "the most common performance pitfall is to traverse or copy data that is accumulated from dependencies"
* ccache
  * direct mode = use the Declared dependencies to derive the cache key
  * preprocessor mode = use the Actual dependencies to derive the cache key
  * the analysis of Actual dependencies is simplified by executing the C preprocessor
    * adding the `-P` flag to the preprocessor will remove source paths -> cheap "content addressed" cache

## pp-trace

trace preprocessor tokens

part of the `clang` package

```
pp-trace --callbacks MacroDefined,MacroExpands,Ifdef,Else,Endif,InclusionDirective,FileChanged main.c -- -DUNUSED_USER_FLAG=1
```

https://clang.llvm.org/extra/doxygen/PPTrace_8cpp_source.html
https://github.com/llvm/llvm-project/tree/main/clang-tools-extra/pp-trace

## cxx implementation

three possible solutions:

1. clang plugin: probably too limited
2. clang wrapper: either expensive (rewrite clang), or slow (double parsing)
3. clang patch, clang fork: could be the simplest solution. not limited by plugin API
  * similar: chromium &rarr; ungoogled-chromium
  * downside: longer compile times. clang = 300 MByte source
  * challenge: patch/rebuild only the "driver" = llvm-project/clang/tools/driver/driver.cpp
    * driver = main entry point of the compiler
    * `std::unique_ptr<Compilation> C(TheDriver.BuildCompilation(Args));`
    * https://clang.llvm.org/doxygen/classclang_1_1driver_1_1Driver.html "logic for constructing compilation processes from a set of gcc-driver-like command line arguments" - sounds good
    * driver CMakeLists.txt
      * llvm-project/clang/tools/driver/CMakeLists.txt
      * llvm-project/clang/lib/Driver/CMakeLists.txt
      * llvm-project/clang/include/clang/Driver/CMakeLists.txt
      * llvm-project/clang/unittests/Driver/CMakeLists.txt


## rust implementation

similar project: [sccache](https://github.com/mozilla/sccache) is also implemented in rust

problem: ffi binding to clang/llvm c++ code

### rust and cxx interop

llvm and clang are written in c++, so we need rust/c++ interop

existing bindings are limited, as they are auto-generated from llvm/clang C headers, not C++ headers

auto-generating rust bindings from C++ headers is a more challenging,
since the tooling ([autocxx](https://github.com/google/autocxx)) is not perfect

* https://cxx.rs/tutorial.html
* https://cxx.rs/context.html?highlight=autocxx#role-of-cxx

#### rust + llvm + clang

throwing llvm + clang at [autocxx](https://github.com/google/autocxx) triggers a bug in autocxx/bindgen:
[thread 'main' panicked at 'Not an item: ItemId(40063)'](https://github.com/google/autocxx/issues/779)

### llvm bindings for rust

* https://github.com/tari/llvm-sys.rs low-level, unsafe, auto-generated from llvm C headers
* https://github.com/TheDan64/inkwell idiomatic, safe
* https://github.com/cdisselkoen/llvm-ir work with LLVM IR in pure safe Rust, no extra FFI calls
  * probably we will not need this

### clang bindings for rust

* https://github.com/KyleMayes/clang-sys low-level, unsafe, auto-generated from clang C headers
* https://github.com/KyleMayes/clang-rs idiomatic, safe

## related

* https://discourse.nixos.org/t/incremental-builds/9988
  * "We will need to develop new incremental builders for each language. This is something I am hoping to tackle in the coming year. PM me if you are interested in participating in that problem space."

