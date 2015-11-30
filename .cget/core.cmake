include(CMakeParseArguments)

cmake_policy(SET CMP0011 NEW)  
cmake_policy(SET CMP0012 NEW)

if(NOT CGET_PACKAGE_DIR)
  SET(CGET_PACKAGE_DIR ${CMAKE_BINARY_DIR}/.cget/packages)
  SET(CGET_INSTALL_DIR ${CMAKE_BINARY_DIR}/.cget/install_root)
endif()

if(CGET_USE_ONLY_CGET_PACKAGES)
  SET(CMAKE_FIND_ROOT_PATH "${CGET_INSTALL_DIR}")
  SET(CMAKE_PREFIX_PATH "${CGET_INSTALL_DIR}")  
else()
  SET(CMAKE_FIND_ROOT_PATH "${CGET_INSTALL_DIR};${CMAKE_FIND_ROOT_PATH}")
  SET(CMAKE_PREFIX_PATH "${CGET_INSTALL_DIR};${CMAKE_PREFIX_PATH}")  
endif()

SET(REL_BUILD_DIR "")

macro(CGET_PARSE_VERSION NAME INPUT RESULT)
  SET(${RESULT} ${${INPUT}})
  STRING(TOLOWER ${${RESULT}} ${RESULT})
  STRING(TOLOWER ${NAME} CGET_${NAME}_LOWER)
  STRING(REPLACE "${CGET_${NAME}_LOWER}" "" ${RESULT} "${${RESULT}}")
  STRING(REGEX MATCH "([0-9]+[\\._]?)+" ${RESULT} "${${RESULT}}")
  STRING(REPLACE "_" "." ${RESULT} "${${RESULT}}")
endmacro()

function(CGET_NORMALIZE_CMAKE_FILES DIR SUFFIX NEW_SUFFIX)
  file(GLOB config_files RELATIVE "${DIR}" "${DIR}/*${SUFFIX}")
  foreach(config_file ${config_files})
    STRING(REPLACE "${SUFFIX}" "" root_name "${config_file}")
    STRING(TOLOWER "${root_name}" root_name)
    execute_process(COMMAND ${CMAKE_COMMAND} -E copy "${DIR}/${config_file}" "${DIR}/${root_name}-${NEW_SUFFIX}")
  endforeach()

endfunction()

function(CGET_BUILD name)
  set(options "")
  set(oneValueArgs GITHUB GIT HG SVN URL REVISION OPTIONS)
  set(multiValueArgs "")
  
  CMAKE_PARSE_ARGUMENTS(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  CGET_PARSE_VERSION(${name} ARGS_VERSION ARGS_CMAKE_VERSION)
  if(NOT ARGS_OPTIONS)
    MESSAGE("Building ${name}...")
  else()
    MESSAGE("Building ${name}... (With: '${ARGS_OPTIONS}')")
  endif()
  set(CGET_${name}_BUILT 0)
  
  set(dir ${CGET_PACKAGE_DIR}/${name}_${ARGS_VERSION})
  file(MAKE_DIRECTORY ${dir}/${REL_BUILD_DIR})
  if(EXISTS ${dir}/CMakeLists.txt)
    separate_arguments(ARGS_OPTIONS)

    STRING(REPLACE ";" "\;" root_path_arg "${CMAKE_FIND_ROOT_PATH}")
    STRING(REPLACE ";" "\;" prefix_path_arg "${CMAKE_PREFIX_PATH}")
    
    set(CMAKE_OPTIONS ${ARGS_OPTIONS}
      -DCMAKE_INSTALL_PREFIX:PATH=${CGET_INSTALL_DIR}
      -DCGET_PACKAGE_DIR=${CGET_PACKAGE_DIR}
      -DCGET_INSTALL_DIR=${CGET_INSTALL_DIR}
      -DCGET_CORE_DIR=${CMAKE_CURRENT_LIST_DIR}/
      )

    if(NOT "${CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
      set(sub_toolchain_file ${CMAKE_TOOLCHAIN_FILE})
      if(NOT IS_ABSOLUTE ${sub_toolchain_file})
	set(sub_toolchain_file ${CMAKE_SOURCE_DIR}/${CMAKE_TOOLCHAIN_FILE})
      endif()
      list(APPEND CMAKE_OPTIONS -DCMAKE_TOOLCHAIN_FILE=${sub_toolchain_file})
    endif()

    
    message("Calling 'cmake ${CMAKE_OPTIONS} -DCMAKE_FIND_ROOT_PATH:PATH=${root_path_arg} -DCMAKE_PREFIX_PATH:PATH=${prefix_path_arg} .")
    execute_process(COMMAND cmake --no-warn-unused-cli ${CMAKE_OPTIONS} -DCMAKE_FIND_ROOT_PATH:PATH=${root_path_arg} -DCMAKE_PREFIX_PATH:PATH=${prefix_path_arg}  .
      WORKING_DIRECTORY ${dir}/${REL_BUILD_DIR})
    execute_process(COMMAND cmake --build . --target install
      WORKING_DIRECTORY ${dir}/${REL_BUILD_DIR})
    set(CGET_${name}_BUILT 1)
  elseif(EXISTS ${dir}/autogen.sh)
    execute_process(COMMAND  ./autogen.sh
      WORKING_DIRECTORY ${dir})
  endif()

  foreach(config_variant configure config)
    if(EXISTS ${dir}/${config_variant})
      execute_process(COMMAND ./${config_variant} --host=${CMAKE_HOST_SYSTEM} --prefix=${CGET_INSTALL_DIR} ${ARGS_OPTIONS}
	WORKING_DIRECTORY ${dir}/${REL_BUILD_DIR})
      execute_process(COMMAND make
	WORKING_DIRECTORY ${dir}/${REL_BUILD_DIR})
      execute_process(COMMAND make install
	WORKING_DIRECTORY ${dir}/${REL_BUILD_DIR})
      set(CGET_${name}_BUILT 1)
    endif()
  endforeach()

  if(NOT CGET_${name}_BUILT)
    file(MOVE ${dir}/${REL_BUILD_DIR} ${dir}/${REL_BUILD_DIR}_fail)
    message(FATAL_ERROR "Couldn't identify build system for ${name}")
  endif()
  
  CGET_NORMALIZE_CMAKE_FILES("${dir}/${REL_BUILD_DIR}" "Config.cmake" "config.cmake")
  CGET_NORMALIZE_CMAKE_FILES("${dir}/${REL_BUILD_DIR}" "ConfigVersion.cmake" "config-version.cmake")
    
endfunction(CGET_BUILD)

function(CGET_GET_PACKAGE name)
  set(options REGISTRY)
  set(oneValueArgs GITHUB GIT HG SVN URL REVISION OPTIONS)
  set(multiValueArgs "")
  
  CMAKE_PARSE_ARGUMENTS(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  CGET_PARSE_VERSION(${name} ARGS_VERSION ARGS_CMAKE_VERSION)

  MESSAGE("Getting ${name}...")

  if(ARGS_REGISTRY)
    set(ARGS_GITHUB "cget/${name}.cget")
  endif()

  if(ARGS_GITHUB)
    set(ARGS_GIT "http://github.com/${ARGS_GITHUB}")
  endif()

  set(STAGING_DIR "${CGET_PACKAGE_DIR}/${name}_${ARGS_VERSION}")

  if(NOT EXISTS ${STAGING_DIR})    
    if(ARGS_GIT)
      if("" STREQUAL "${ARGS_VERSION}")
	set(ARGS_VERSION "master")
      endif()
      execute_process(COMMAND git clone ${ARGS_GIT} ${STAGING_DIR} -q --progress --branch=${ARGS_VERSION} --depth=1
	WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
      
    endif()
  
  endif()
endfunction(CGET_GET_PACKAGE)

function(CGET_HAS_DEPENDENCY name)
  set(options NO_FIND_PACKAGE)
  set(oneValueArgs GITHUB GIT HG SVN URL VERSION OPTIONS)
  set(multiValueArgs "")
  
  CMAKE_PARSE_ARGUMENTS(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  CGET_PARSE_VERSION(${name} ARGS_VERSION ARGS_CMAKE_VERSION)

  set(${name}_DIR ${CGET_PACKAGE_DIR}/${name}_${ARGS_VERSION}/${REL_BUILD_DIR})
  if(NOT EXISTS ${${name}_DIR})
    CGET_GET_PACKAGE(${ARGV})   
    CGET_BUILD(${ARGV})
  ENDIF()

  if(NOT EXISTS ARGS_NO_FIND_PACKAGE)
    find_package(${name} ${ARGS_CMAKE_VERSION} )
  endif()
  
  IF(${${name}_FOUND})
    message("Found ${name}-${ARGS_CMAKE_VERSION}")
  ENDIF()
endfunction(CGET_HAS_DEPENDENCY) 
