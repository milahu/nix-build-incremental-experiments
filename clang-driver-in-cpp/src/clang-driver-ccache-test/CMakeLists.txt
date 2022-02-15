cmake_minimum_required(VERSION 3.13.4)

project(clang-driver-ccache-test)

set(CMAKE_CXX_STANDARD 14 CACHE STRING "C++ standard to conform to")
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

#add_clang_tool(clang # FIXME Unknown CMake command "add_clang_tool".
add_executable(${PROJECT_NAME}
  test.cc
  )

install(TARGETS ${PROJECT_NAME})
