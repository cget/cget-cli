cmake_minimum_required (VERSION 2.6) 
project (cget C CXX)

find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
  message("Using ccache...")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)

set(CGET_USE_ONLY_CGET_PACKAGES ON)
include(package.cmake)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")

add_executable(XXD ./ThirdParty/xxd/xxd.c)
#get_property(xxd_location TARGET XXD PROPERTY LOCATION)

add_custom_command(
  OUTPUT src/generated/cget_core_cmake.h
  COMMAND $<TARGET_FILE:XXD> -i .cget/core.cmake src/generated/cget_core_cmake.h
  DEPENDS        .cget/core.cmake
  DEPENDS XXD
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  )

include_directories(include
  ${gflags_INCLUDE_DIR}
  ${CURL_INCLUDE_DIR}
  ${RAPIDJSON_INCLUDE_DIRS}
  )


add_library(cget STATIC src/utilities.cc src/generated/cget_core_cmake.h)
target_link_libraries(cget)

add_executable(cget-cli
  src/main.cc
  src/main-init.cc
  src/main-install.cc

  src/github-search.cc
  src/cmake-utils.cc
)

find_library(LIB_GIT2 git2 NAMES git2 git2d)

target_link_libraries(cget-cli cget
  ${gflags_LIBRARIES}
  ${CURL_LIBRARY}
  ${LIB_GIT2}
  )
set_target_properties(cget-cli PROPERTIES OUTPUT_NAME cget)

install(TARGETS cget-cli DESTINATION bin)
install(DIRECTORY ${CGET_INSTALL_DIR}/ DESTINATION /)

set( CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin )
set( CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin )
set( CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin )

INCLUDE(InstallRequiredSystemLibraries)

SET(CPACK_PACKAGE_DESCRIPTION_SUMMARY "CGet CLI tool")
SET(CPACK_PACKAGE_VERSION_MAJOR "0")
SET(CPACK_PACKAGE_VERSION_MINOR "3")
SET(CPACK_PACKAGE_VERSION_PATCH "0")
SET(CPACK_PACKAGE_INSTALL_DIRECTORY "CGet ${CMake_VERSION_MAJOR}.${CMake_VERSION_MINOR}")
IF(WIN32 AND NOT UNIX)
  # There is a bug in NSI that does not handle full unix paths properly. Make
  # sure there is at least one set of four (4) backlasshes.
  SET(CPACK_NSIS_DISPLAY_NAME "${CPACK_PACKAGE_INSTALL_DIRECTORY} CGet")
  SET(CPACK_NSIS_MODIFY_PATH ON)
ELSE(WIN32 AND NOT UNIX)
  SET(CPACK_STRIP_FILES "bin/cget-cli")
  SET(CPACK_SOURCE_STRIP_FILES "")
ENDIF(WIN32 AND NOT UNIX)
SET(CPACK_PACKAGE_EXECUTABLES "cget-cli" "CGet command line tool")
INCLUDE(CPack)
