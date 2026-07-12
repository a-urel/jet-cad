cmake_minimum_required(VERSION 3.24)
project(jet_cad_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
option(JET_CAD_BUILD_TESTS "Build GoogleTest targets" ON)

find_package(OpenCASCADE REQUIRED)

include(FetchContent)
FetchContent_Declare(nlohmann_json
  URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz)
FetchContent_MakeAvailable(nlohmann_json)

add_library(jet_cad_native SHARED
  api.cpp
  session.cpp
)
target_include_directories(jet_cad_native PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(jet_cad_native PRIVATE nlohmann_json::nlohmann_json)

# OCCT toolkits. 7.8+ renamed STEP toolkits (TKSTEP -> TKDESTEP); support both.
set(JET_CAD_OCCT_LIBS
  TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo
  TKPrim TKBO TKFillet TKShHealing TKXSBase)
if(TARGET TKDESTEP)
  list(APPEND JET_CAD_OCCT_LIBS TKDESTEP)
else()
  list(APPEND JET_CAD_OCCT_LIBS TKSTEP TKSTEPBase TKSTEPAttr TKSTEP209)
endif()
target_include_directories(jet_cad_native PRIVATE ${OpenCASCADE_INCLUDE_DIR})
target_link_libraries(jet_cad_native PRIVATE ${JET_CAD_OCCT_LIBS})

if(JET_CAD_BUILD_TESTS)
  FetchContent_Declare(googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.tar.gz)
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
  enable_testing()
  add_executable(jet_cad_native_tests
    tests/smoke_test.cpp
    tests/session_test.cpp
    tests/boolean_test.cpp
    tests/modeling_test.cpp
    tests/persistence_test.cpp
  )
  # session.hpp/session_test.cpp include and call into OCCT directly
  # (TopoDS_Shape, BRepPrimAPI_MakeBox, BRepGProp, ...). jet_cad_native's
  # OCCT include dir and libs are PRIVATE, so neither propagates to this
  # target via target_link_libraries below. Add both explicitly.
  target_include_directories(jet_cad_native_tests PRIVATE ${OpenCASCADE_INCLUDE_DIR})
  target_link_libraries(jet_cad_native_tests PRIVATE
    jet_cad_native ${JET_CAD_OCCT_LIBS} nlohmann_json::nlohmann_json GTest::gtest_main)
  include(GoogleTest)
  # DISCOVERY_TIMEOUT: the test binary links ~24 OCCT shared libraries;
  # the first (cold) launch pays dyld/codesign verification overhead on
  # freshly-built/Homebrew dylibs (~6s measured on macOS arm64 here),
  # which exceeds gtest_discover_tests' 5s default and fails configure-time
  # test discovery. 60s gives ample headroom while staying well short of
  # a real hang.
  gtest_discover_tests(jet_cad_native_tests DISCOVERY_TIMEOUT 60)
endif()
