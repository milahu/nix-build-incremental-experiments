cmake_minimum_required(VERSION 3.13.4)

project(clang-driver-ccache)

# based on llvm-project/clang/CMakeLists.txt
# based on https://stackoverflow.com/questions/55921707/setting-path-to-clang-library-in-cmake
# based on https://github.com/patrykstefanski/dc-lang/blob/master/CMakeLists.txt

set(CMAKE_CXX_STANDARD 14 CACHE STRING "C++ standard to conform to")
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

# TODO
# Support plugins.
#option(CLANG_PLUGIN_SUPPORT "Build clang with plugin support" ON)
#if(CLANG_PLUGIN_SUPPORT)
#  set(support_plugins SUPPORT_PLUGINS)
#endif()

# Find CMake file for Clang
find_package(Clang REQUIRED CONFIG)
#message(STATUS "Found Clang ${CLANG_PACKAGE_VERSION}")

#find_package(LLVM REQUIRED CONFIG)
#message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")

# Add path to LLVM modules
set(CMAKE_MODULE_PATH
  ${CMAKE_MODULE_PATH}
  "${LLVM_CMAKE_DIR}"
)

# import LLVM CMake functions
include(AddLLVM)

include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${CLANG_INCLUDE_DIRS})

add_definitions(${LLVM_DEFINITIONS})
add_definitions(${CLANG_DEFINITIONS})

# based on llvm-project/clang/tools/driver/CMakeLists.txt

set( LLVM_LINK_COMPONENTS
  ${LLVM_TARGETS_TO_BUILD}
  Analysis
  CodeGen
  Core
  IPO
  AggressiveInstCombine
  InstCombine
  Instrumentation
  MC
  MCParser
  ObjCARCOpts
  Option
  ScalarOpts
  Support
  TransformUtils
  Vectorize
  )


# Support plugins.
if(CLANG_PLUGIN_SUPPORT)
  set(support_plugins SUPPORT_PLUGINS)
endif()




#add_clang_tool(clang # FIXME Unknown CMake command "add_clang_tool".
add_executable(${PROJECT_NAME}
  driver.cpp
  cc1_main.cpp
  cc1as_main.cpp
  cc1gen_reproducer_main.cpp

  #DEPENDS # FIXME Cannot find source file: DEPENDS
  #intrinsics_gen # TODO https://reviews.llvm.org/D83454 provided by llvm?
  #${support_plugins} # TODO
  )

add_dependencies(${PROJECT_NAME}
  intrinsics_gen
  )

#clang_target_link_libraries(clang
target_link_libraries(${PROJECT_NAME}
  PRIVATE
  clangBasic
  clangCodeGen
  clangDriver
  clangFrontend
  clangFrontendTool
  clangSerialization
  )

install(TARGETS ${PROJECT_NAME})

if(WIN32 AND NOT CYGWIN)
  # Prevent versioning if the buildhost is targeting for Win32.
else()
  set_target_properties(${PROJECT_NAME} PROPERTIES VERSION ${CLANG_EXECUTABLE_VERSION})
endif()

# Support plugins.
if(CLANG_PLUGIN_SUPPORT)
  export_executable_symbols_for_plugins(${PROJECT_NAME})
endif()

# TODO clang-resource-headers ?
#add_dependencies(${PROJECT_NAME} clang-resource-headers)

if(NOT CLANG_LINKS_TO_CREATE)
  set(CLANG_LINKS_TO_CREATE clang++ clang-cl clang-cpp)
endif()



# Unknown CMake command "add_clang_symlink".
# grep: macro(add_clang_symlink
#   llvm-project/clang/cmake/modules/AddClang.cmake
#     macro(add_clang_symlink name dest)
#foreach(link ${CLANG_LINKS_TO_CREATE})
#  add_clang_symlink(${link} ${PROJECT_NAME})
#endforeach()

# FIXME symlinks are not in $out/bin
# workaround in clang-driver-ccache.nix
macro(add_symlink sympath filepath)
  install(CODE "execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink ${filepath} ${sympath})")
  install(CODE "message(\"-- Created symlink: ${sympath} -> ${filepath}\")")
endmacro(add_symlink)

foreach(link ${CLANG_LINKS_TO_CREATE})
  add_symlink(${link} ${PROJECT_NAME})
endforeach()

if(NOT ${PROJECT_NAME} STREQUAL "clang")
  add_symlink("clang" ${PROJECT_NAME})
endif()



# Configure plist creation for OS X.
set (TOOL_INFO_PLIST "Info.plist" CACHE STRING "Plist name")
if (APPLE)
  if (CLANG_VENDOR)
    set(TOOL_INFO_NAME "${CLANG_VENDOR} clang")
  else()
    set(TOOL_INFO_NAME "clang")
  endif()

  set(TOOL_INFO_UTI "${CLANG_VENDOR_UTI}")
  set(TOOL_INFO_VERSION "${CLANG_VERSION}")
  set(TOOL_INFO_BUILD_VERSION "${LLVM_VERSION_MAJOR}.${LLVM_VERSION_MINOR}")

  set(TOOL_INFO_PLIST_OUT "${CMAKE_CURRENT_BINARY_DIR}/${TOOL_INFO_PLIST}")
  target_link_libraries(${PROJECT_NAME}
    PRIVATE
    "-Wl,-sectcreate,__TEXT,__info_plist,${TOOL_INFO_PLIST_OUT}")
  configure_file("${TOOL_INFO_PLIST}.in" "${TOOL_INFO_PLIST_OUT}" @ONLY)

  set(TOOL_INFO_UTI)
  set(TOOL_INFO_NAME)
  set(TOOL_INFO_VERSION)
  set(TOOL_INFO_BUILD_VERSION)
endif()

if(CLANG_ORDER_FILE AND
    (LLVM_LINKER_IS_LD64 OR LLVM_LINKER_IS_GOLD OR LLVM_LINKER_IS_LLD))
  include(LLVMCheckLinkerFlag)

  if (LLVM_LINKER_IS_LD64)
    set(LINKER_ORDER_FILE_OPTION "-Wl,-order_file,${CLANG_ORDER_FILE}")
  elseif (LLVM_LINKER_IS_GOLD)
    set(LINKER_ORDER_FILE_OPTION "-Wl,--section-ordering-file,${CLANG_ORDER_FILE}")
  elseif (LLVM_LINKER_IS_LLD)
    set(LINKER_ORDER_FILE_OPTION "-Wl,--symbol-ordering-file,${CLANG_ORDER_FILE}")
  endif()

  # This is a test to ensure the actual order file works with the linker.
  llvm_check_linker_flag(CXX ${LINKER_ORDER_FILE_OPTION} LINKER_ORDER_FILE_WORKS)

  # Passing an empty order file disables some linker layout optimizations.
  # To work around this and enable workflows for re-linking when the order file
  # changes we check during configuration if the file is empty, and make it a
  # configuration dependency.
  file(READ ${CLANG_ORDER_FILE} ORDER_FILE LIMIT 20)
  if("${ORDER_FILE}" STREQUAL "\n")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${CLANG_ORDER_FILE})
  elseif(LINKER_ORDER_FILE_WORKS)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${LINKER_ORDER_FILE_OPTION})
    set_target_properties(${PROJECT_NAME} PROPERTIES LINK_DEPENDS ${CLANG_ORDER_FILE})
  endif()
endif()
