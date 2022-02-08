// based on https://github.com/KyleMayes/clang-rs/blob/master/examples/structs.rs
// based on https://clang.llvm.org/extra/doxygen/PPTrace_8cpp_source.html
// based on https://cxx.rs/tutorial.html
// based on https://github.com/google/autocxx

//use autocxx::prelude::*;

autocxx::prelude::include_cpp! {
    #include "clang/Tooling/CommonOptionsParser.h" // your header file name
    safety!(unsafe) // see details of unsafety policies described in include_cpp
    generate!("clang::tooling::CommonOptionsParser::create") // add this line for each function or type you wish to generate
}

/*
extern crate clang;
extern crate clang-sys; // tooling::CommonOptionsParser
*/

/*
#[cxx::bridge]
mod clang_ffi {
    unsafe extern "C++" {
        /*
        include!("clang/AST/ASTConsumer.h");
        include!("clang/AST/ASTContext.h");
        include!("clang/Basic/SourceManager.h");
        include!("clang/Driver/Options.h");
        include!("clang/Frontend/CompilerInstance.h");
        include!("clang/Frontend/FrontendAction.h");
        include!("clang/Frontend/FrontendActions.h");
        include!("clang/Lex/Preprocessor.h");
        include!("clang/Tooling/Execution.h");
        include!("clang/Tooling/Tooling.h");
        include!("llvm/Option/Arg.h");
        include!("llvm/Option/ArgList.h");
        include!("llvm/Option/OptTable.h");
        include!("llvm/Option/Option.h");
        include!("llvm/Support/CommandLine.h");
        include!("llvm/Support/FileSystem.h");
        include!("llvm/Support/GlobPattern.h");
        include!("llvm/Support/InitLLVM.h");
        include!("llvm/Support/Path.h");
        include!("llvm/Support/ToolOutputFile.h");
        include!("llvm/Support/WithColor.h");
        */
        include!("clang/Tooling/CommonOptionsParser.h");
        type BlobstoreClient;

        fn new_blobstore_client() -> UniquePtr<BlobstoreClient>;
    }
}
fn main() {
    let client = clang_ffi::new_blobstore_client();
}
*/

//use clang::*;

fn main(argc: auto, argv: auto) {
    let OptionsParser = ffi::clang::tooling::CommonOptionsParser::create(
        argc, argv, 0, // Cat,
        0, // llvm::cl::ZeroOrMore
    );
}

/*
fn main(argc: auto, argv: auto) {
    // Acquire an instance of `Clang`
    let clang_instance = clang::Clang;
    //let clang = clang::Clang::new().unwrap(); // https://github.com/KyleMayes/clang-rs/issues/35
    // This violates the requirement that only one Clang object exists per thread

    let OptionsParser = clang::tooling::CommonOptionsParser::create(
        argc, argv, Cat, llvm::cl::ZeroOrMore);



    // Create a new `Index`
    let index = clang::Index::new(&clang_instance, false, false);

    // Parse a source file into a translation unit
    let tu = index.parser("src/structs.c").parse().unwrap();

    // Get the structs in this translation unit
    let structs = tu.get_entity().get_children().into_iter().filter(|e| {
        e.get_kind() == clang::EntityKind::StructDecl
    }).collect::<Vec<_>>();

    // Print information about the structs
    for struct_ in structs {
        let type_ =  struct_.get_type().unwrap();
        let size = type_.get_sizeof().unwrap();
        println!("struct: {:?} (size: {} bytes)", struct_.get_name().unwrap(), size);

        for field in struct_.get_children() {
            let name = field.get_name().unwrap();
            let offset = type_.get_offsetof(&name).unwrap();
            println!("    field: {:?} (offset: {} bits)", name, offset);
        }
    }
}
*/
