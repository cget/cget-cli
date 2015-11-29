cmake_minimum_required (VERSION 2.6) 
project (cget C CXX)

find_program(CCACHE_FOUND ccache)
if(CCACHE_FOUND)
  message("Using ccache...")
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
endif(CCACHE_FOUND)

#set(CGET_USE_ONLY_CGET_PACKAGES On)
include(package.cmake)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")

add_custom_command(
  OUTPUT src/generated/cget_core_cmake.h
  COMMAND xxd -i .cget/core.cmake src/generated/cget_core_cmake.h
  DEPENDS        .cget/core.cmake
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  )

include_directories(include
  ${gflags_INCLUDE_DIR}
  ${CURL_INCLUDE_DIR}
  ${RapidJSON_LIBRARY}
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

target_link_libraries(cget-cli cget
  ${gflags_LIBRARIES}
  ${CURL_LIBRARY}
  ${RapidJSON_LIBRARY}
  )
set_target_properties(cget-cli PROPERTIES OUTPUT_NAME cget)
