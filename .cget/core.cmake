include(CMakeParseArguments)

cmake_policy(SET CMP0011 NEW)
cmake_policy(SET CMP0012 NEW)

if (NOT DEFINED CGET_VERBOSE_LEVEL)
  set(CGET_VERBOSE_LEVEL 2)
endif()

if (NOT DEFINED CGET_CORE_DIR)
  set(CGET_CORE_DIR "${CMAKE_SOURCE_DIR}/")
  set(CGET_IS_ROOT_DIR ON)

  ADD_CUSTOM_TARGET(cget-clean-packages COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_BIN_DIR}")
  ADD_CUSTOM_TARGET(cget-rebuild-packages)
endif()

FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_CORE_HASH)
FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_PACKAGE_HASH)

set(CGET_CORE_VERSION 0.1.4)

if (NOT CGET_BIN_DIR)
  SET(CGET_BIN_DIR "${CMAKE_SOURCE_DIR}/.cget-bin/")
endif ()

function(CGET_MESSAGE LVL)
  if(NOT CGET_VERBOSE_LEVEL LESS LVL)
    message("cget: ${ARGN}")
  endif()
endfunction()

macro(CGET_EXECUTE_PROCESS)
  CGET_MESSAGE(3 "Running exec process: ${ARGN}")
  execute_process(${ARGN} RESULT_VARIABLE EXECUTE_RESULT)
  if(EXECUTE_RESULT)
    message(FATAL_ERROR "Execute process failed with ${EXECUTE_RESULT} -- ${ARGN}")
  endif()
endmacro()

if (NOT CGET_PACKAGE_DIR)
  SET(CGET_PACKAGE_DIR ${CGET_BIN_DIR}/packages)
endif ()

SET(CGET_INSTALL_DIR ${CGET_BIN_DIR}/install_root/${CMAKE_GENERATOR})

set(CGET_BUILD_CONFIGS ${CMAKE_CONFIGURATION_TYPES})
if(NOT CGET_BUILD_CONFIGS)
        set(CGET_BUILD_CONFIGS ${CMAKE_BUILD_TYPE})
    else()
        set(CGET_BUILD_CONFIGS "Debug;Release")
endif()

set(CGET_VERBOSE_SUFFIX OFF)

IF(CGET_VERBOSE_SUFFIX)
    SET(OLD_SUFFIX "${CMAKE_FIND_LIBRARY_SUFFIXES}")
    SET(CMAKE_FIND_LIBRARY_SUFFIXES)
    foreach(suffix ${OLD_SUFFIX})
        foreach(configuration ${CGET_BUILD_CONFIGS})
            list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES "_${configuration}${suffix}")
        endforeach()
    endforeach()   
    CGET_MESSAGE(3 "${OLD_SUFFIX} vs ${CMAKE_FIND_LIBRARY_SUFFIXES}")
ELSE()
    set(CMAKE_DEBUG_POSTFIX "d")
ENDIF()
    
set(CMAKE_FIND_ROOT_PATH ${CGET_INSTALL_DIR})
list(APPEND CMAKE_PREFIX_PATH ${CGET_INSTALL_DIR} ${CGET_INSTALL_DIR}/lib/cmake)
set(CMAKE_LIBRARY_PATH ${CGET_INSTALL_DIR}/lib)

list(APPEND CMAKE_INSTALL_RPATH ${CMAKE_LIBRARY_PATH})

CGET_MESSAGE(3 "Install dir: ${CGET_INSTALL_DIR}")
CGET_MESSAGE(3 "Bin dir: ${CGET_BIN_DIR}")

include_directories(${CGET_INSTALL_DIR}/include)
link_directories(${CGET_INSTALL_DIR} ${CMAKE_LIBRARY_PATH})

function(CGET_WRITE_CGET_SETTINGS_FILE)
  set(WRITE_STR "SET(CMAKE_INSTALL_PREFIX \t\"${CGET_INSTALL_DIR}\" CACHE PATH \"\")\n")    
  foreach(varname CGET_BIN_DIR CMAKE_CONFIGURATION_TYPES CMAKE_INSTALL_RPATH CGET_PACKAGE_DIR CGET_INSTALL_DIR CGET_CORE_DIR CMAKE_FIND_ROOT_PATH CMAKE_PREFIX_PATH CMAKE_LIBRARY_PATH BUILD_SHARED_LIBS CMAKE_FIND_LIBRARY_SUFFIXES)
    if(DEFINED ${varname})
      set(WRITE_STR "${WRITE_STR}SET(${varname} \t\"${${varname}}\" CACHE STRING \"\")\n")
    endif()
  endforeach()
  
  
  foreach(configuration ${CGET_BUILD_CONFIGS})
    STRING(TOUPPER ${configuration} configuration_upper)
    IF(CGET_VERBOSE_SUFFIX)    
      set(WRITE_STR "${WRITE_STR}SET(CMAKE_${configuration_upper}_POSTFIX \t\"_${configuration_upper}\" CACHE STRING \"\")\n")      
    elseif(DEFINED CMAKE_${configuration_upper}_POSTFIX)
      set(WRITE_STR "${WRITE_STR}SET(CMAKE_${configuration_upper}_POSTFIX \t\"${CMAKE_${configuration_upper}_POSTFIX}\" CACHE STRING \"\")\n")      
    endif()
  endforeach()    
  

  CGET_MESSAGE(2 "Writing load file to ${CGET_BIN_DIR}/load.cmake")
  file(WRITE "${CGET_BIN_DIR}/load.cmake" "${WRITE_STR}")    
endfunction()

if(CGET_IS_ROOT_DIR)
  CGET_WRITE_CGET_SETTINGS_FILE()
endif()

macro(CGET_PARSE_VERSION NAME INPUT RESULT)
  SET(${RESULT} ${${INPUT}})
  STRING(TOLOWER "${${RESULT}}" ${RESULT})
  STRING(TOLOWER ${NAME} CGET_${NAME}_LOWER)
  STRING(REPLACE "${CGET_${NAME}_LOWER}" "" ${RESULT} "${${RESULT}}")
  STRING(REGEX MATCH "([0-9]+[\\._]?)+" ${RESULT} "${${RESULT}}")
  STRING(REPLACE "_" "." ${RESULT} "${${RESULT}}")
endmacro()

function(CGET_NORMALIZE_CMAKE_FILES DIR SUFFIX NEW_SUFFIX)
  file(GLOB config_files RELATIVE "${DIR}" "${DIR}/*${SUFFIX}")
  foreach (config_file ${config_files})
    STRING(REPLACE "${SUFFIX}" "" root_name "${config_file}")
    STRING(TOLOWER "${root_name}" root_name)
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E copy "${DIR}/${config_file}" "${DIR}/${root_name}-${NEW_SUFFIX}")
  endforeach ()

endfunction()

SET(REL_BUILD_DIR "build-${CMAKE_GENERATOR}")
if(CMAKE_BUILD_TYPE)
  SET(RELEASE_REL_BUILD_DIR "${REL_BUILD_DIR}-Release")  
  SET(REL_BUILD_DIR "${REL_BUILD_DIR}-${CMAKE_BUILD_TYPE}")
endif()

macro(CGET_FILE_CONTENTS filename var)
  if(EXISTS ${filename})
    file(READ ${filename} "${var}")
  endif()
endmacro()

CGET_FILE_CONTENTS("${CGET_INSTALL_DIR}/.install" INSTALL_CACHE_VAL)  
if (NOT INSTALL_CACHE_VAL STREQUAL CGET_CORE_VERSION)
    CGET_MESSAGE(3 "Install out of date ${INSTALL_CACHE_VAL} vs ${CGET_CORE_VERSION}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_INSTALL_DIR}")
    
    file(WRITE "${CGET_INSTALL_DIR}/.install" "${CGET_CORE_VERSION}")
endif ()

macro(CGET_PARSE_OPTIONS name)
  set(options NO_FIND_PACKAGE REGISTRY NOSUBMODULES PROXY)
  set(oneValueArgs GITHUB GIT HG SVN URL VERSION FINDNAME COMMITID REGISTRY_VERSION OPTIONS_FILE)
  set(multiValueArgs OPTIONS FIND_OPTIONS)

  CMAKE_PARSE_ARGUMENTS(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  CGET_PARSE_VERSION(${name} ARGS_VERSION ARGS_CMAKE_VERSION)

  CGET_MESSAGE(5 "PARSE_OPTIONS ${ARGV} ")
  if (ARGS_REGISTRY)
    set(ARGS_GITHUB "cget/${name}.cget")
    set(ARGS_PROXY ON)
  endif ()

  if (ARGS_GITHUB)
    set(ARGS_GIT "http://github.com/${ARGS_GITHUB}")
  endif ()
    
  string(MD5 Repo_Hash "${name} ${ARGS_GIT} ${ARGS_VERSION} ${NOSUBMODULES}")
  string(MD5 Build_Hash "${name} ${ARGS_OPTIONS} ${ARGS_NOSUBMODULES} ${CGET_BUILD_CONFIGS} ${CGET_CORE_VERSION}")

  set(REPO_DIR_SUFFIX ${ARGS_VERSION})
  if("" STREQUAL "${ARGS_VERSION}")
    set(REPO_DIR_SUFFIX "HEAD")
  endif()

  SET(CHECKOUT_TAG "${ARGS_VERSION}")
  if (ARGS_PROXY)
    SET(CGET_REQUESTED_VERSION ${ARGS_VERSION})
    SET(CHECKOUT_TAG "${ARGS_REGISTRY_VERSION}")
  endif()
  
  if(ARGS_PROXY)
    set(REPO_DIR_SUFFIX "${REPO_DIR_SUFFIX}.cget")
  endif()

  set(REPO_DIR "${CGET_PACKAGE_DIR}/${name}_${REPO_DIR_SUFFIX}")
  set(BUILD_DIR "${REPO_DIR}/${REL_BUILD_DIR}")
  set(RELEASE_BUILD_DIR "${REPO_DIR}/${RELEASE_REL_BUILD_DIR}")
  
  if(NOT ARGS_PROXY)
    set(CGET_${name}_REPO_DIR "${REPO_DIR}" CACHE STRING "" FORCE)
    set(CGET_${name}_BUILD_DIR "${BUILD_DIR}" CACHE STRING "" FORCE)
  endif()
endmacro()

macro(CGET_BUILD_CMAKE name)
  CGET_PARSE_OPTIONS(${ARGV})
  separate_arguments(ARGS_OPTIONS)

  set(CMAKE_ROOT ${REPO_DIR})	
  if(NOT EXISTS ${REPO_DIR}/CMakeLists.txt)
    set(CMAKE_ROOT ${REPO_DIR}/cmake)
  endif()

  if(NOT DEFINED ARGS_OPTIONS_FILE)
    SET(ARGS_OPTIONS_FILE ${CGET_BIN_DIR}/load.cmake)
  endif()
  
  set(CMAKE_OPTIONS ${ARGS_OPTIONS}
    -C${ARGS_OPTIONS_FILE}
    -G${CMAKE_GENERATOR}
    --no-warn-unused-cli            
    )

  if (ARGS_PROXY)
    list(APPEND CMAKE_OPTIONS -DCGET_REQUESTED_VERSION=${CGET_REQUESTED_VERSION})
  endif()
  
  if (NOT "${CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
    set(sub_toolchain_file ${CMAKE_TOOLCHAIN_FILE})
    if (NOT IS_ABSOLUTE ${sub_toolchain_file})
      set(sub_toolchain_file ${CGET_CORE_DIR}/${CMAKE_TOOLCHAIN_FILE})
    endif ()
    list(APPEND CMAKE_OPTIONS -DCMAKE_TOOLCHAIN_FILE=${sub_toolchain_file})
  endif ()

  if(DEFINED CMAKE_BUILD_TYPE)
    FILE(MAKE_DIRECTORY ${RELEASE_BUILD_DIR})
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY ${BUILD_DIR})
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE}               WORKING_DIRECTORY ${BUILD_DIR})
    
    # Some find configs only care about the release package, so build that too
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Release             ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY ${RELEASE_BUILD_DIR})
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config Release                           WORKING_DIRECTORY ${RELEASE_BUILD_DIR})
  else()

    # Set up the packages
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY ${BUILD_DIR})

    # Do a build for reach configuration
    CGET_MESSAGE(1 "Building ${CGET_BUILD_CONFIGS}")
    foreach(configuration ${CGET_BUILD_CONFIGS})
      CGET_MESSAGE(2 " ${CMAKE_COMMAND} --build . --target install --config ${configuration} WORKING_DIRECTORY ${BUILD_DIR}")	
      # Some builds define configuration types all their own, so we can't fail here if the config doesn't exist
      EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config ${configuration} WORKING_DIRECTORY ${BUILD_DIR})
    endforeach()
  endif()
endmacro()

macro(CGET_BUILD_AUTOCONF name)
  CGET_PARSE_OPTIONS(${ARGV})
  separate_arguments(ARGS_OPTIONS)

  
endmacro()

function(CGET_BUILD name)
  CGET_PARSE_OPTIONS(${ARGV})

  if (NOT ARGS_OPTIONS)
    CGET_MESSAGE(1 "Building ${name}...")
  else ()
    CGET_MESSAGE(1 "Building ${name}... (With: '${ARGS_OPTIONS}')")
  endif ()
  set(CGET_${name}_BUILT 0)

  set(dir ${CGET_PACKAGE_DIR}/${name}_${CHECKOUT_TAG})
  file(MAKE_DIRECTORY ${BUILD_DIR})

  if (EXISTS ${REPO_DIR}/include.cmake)
    set(CGET_${name}_BUILT 1)
  elseif (EXISTS ${REPO_DIR}/CMakeLists.txt OR EXISTS ${REPO_DIR}/cmake/CMakeLists.txt)
    CGET_BUILD_CMAKE(${ARGV})
    set(CGET_${name}_BUILT 1)
  elseif (EXISTS ${REPO_DIR}/autogen.sh)
    CGET_EXECUTE_PROCESS(COMMAND ./autogen.sh WORKING_DIRECTORY ${REPO_DIR})
  endif ()
 
  foreach (config_variant configure config)
    if (NOT CGET_${name}_BUILT AND EXISTS ${REPO_DIR}/${config_variant})
      STRING(REPLACE " " " " CGET_INSTALL_DIR_SAFE "${CGET_INSTALL_DIR}")
      message("---> ${CGET_INSTALL_DIR_SAFE}")
      CGET_EXECUTE_PROCESS(COMMAND ./${config_variant} --prefix="${CGET_INSTALL_DIR_SAFE}" ${ARGS_OPTIONS}
        WORKING_DIRECTORY ${REPO_DIR})
      CGET_EXECUTE_PROCESS(COMMAND make
        WORKING_DIRECTORY ${REPO_DIR})
      CGET_EXECUTE_PROCESS(COMMAND make install
        WORKING_DIRECTORY ${REPO_DIR})
      set(CGET_${name}_BUILT 1)
    endif ()
  endforeach ()

  if (NOT CGET_${name}_BUILT)
    message(FATAL_ERROR "Couldn't identify build system for ${name} in ${REPO_DIR}")
  endif ()

  CGET_NORMALIZE_CMAKE_FILES("${BUILD_DIR}" "Config.cmake" "config.cmake")
  CGET_NORMALIZE_CMAKE_FILES("${BUILD_DIR}" "ConfigVersion.cmake" "config-version.cmake")

endfunction(CGET_BUILD)

function(CGET_DIRECT_GET_PACKAGE name)
  CGET_PARSE_OPTIONS(${ARGV})
  CGET_MESSAGE(3 "CGET_DIRECT_GET_PACKAGE ${ARGV}")
  CGET_MESSAGE(1 "Getting ${name}...")

  set(GIT_SUBMODULE_OPTIONS "--recursive")
  if (ARGS_NOSUBMODULES)
    set(GIT_SUBMODULE_OPTIONS "")
  endif ()

  set(STAGING_DIR "${REPO_DIR}")

  if (NOT EXISTS ${STAGING_DIR})
    if (ARGS_GIT)
      if ("" STREQUAL "${CHECKOUT_TAG}")
        set(CHECKOUT_TAG "master")
      endif ()
           
      if(ARGS_COMMITID)
	set(_GIT_OPTIONS -n)
      else()
	set(_GIT_OPTIONS --progress --branch=${CHECKOUT_TAG} --depth=1)	
      endif()
      
      CGET_EXECUTE_PROCESS(COMMAND git clone ${ARGS_GIT} ${STAGING_DIR} ${_GIT_OPTIONS} ${GIT_SUBMODULE_OPTIONS}
        WORKING_DIRECTORY ${CGET_CORE_DIR})

      if(ARGS_COMMITID)
	CGET_EXECUTE_PROCESS(COMMAND git checkout ${ARGS_COMMIT_ID} WORKING_DIRECTORY ${STAGING_DIR})	
      endif()
      
    endif ()

  endif ()
endfunction()

function(CGET_GET_PACKAGE)
  CGET_MESSAGE(5 "CGET_GET_PACKAGE ${ARGV}")
  
  CGET_PARSE_OPTIONS(${ARGV})  
  CGET_FILE_CONTENTS("${REPO_DIR}/.retrieved" REPO_CACHE_VAL)
  if (NOT REPO_CACHE_VAL STREQUAL Repo_Hash)
    CGET_MESSAGE(3 "Repo out of date ${REPO_CACHE_VAL} vs ${Repo_Hash}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${REPO_DIR}")
    CGET_DIRECT_GET_PACKAGE(${ARGV})
    file(WRITE "${REPO_DIR}/.retrieved" "${Repo_Hash}")
  ENDIF ()

  CGET_MESSAGE(5 "EXIT CGET_GET_PACKAGE ${ARGV}")
endfunction()

function(CGET_HAS_DEPENDENCY name)
  CGET_PARSE_OPTIONS(${ARGV})
  CGET_MESSAGE(5 "CGET_HAS_DEPENDENCY ${ARGV}")
  CGET_MESSAGE(2 "Checking out ${name}(${CHECKOUT_TAG}) into ${REPO_DIR}, building in ${BUILD_DIR}" )
  
  CGET_GET_PACKAGE(${ARGV})
  
  CGET_FILE_CONTENTS("${BUILD_DIR}/.built" BUILD_CACHE_VAL)  
  if(EXISTS "${REPO_DIR}/include.cmake" )
    set(ARGS_NO_FIND_PACKAGE ON)
    CGET_MESSAGE(3 "Including ${REPO_DIR}/include.cmake")
    include("${REPO_DIR}/include.cmake")
  elseif (NOT BUILD_CACHE_VAL STREQUAL Build_Hash)
    CGET_MESSAGE(3 "Build out of date ${BUILD_CACHE_VAL} vs ${Build_Hash}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${BUILD_DIR}")
    IF(DEFINED RELEASE_BUILD_DIR)
      CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${RELEASE_BUILD_DIR}")
    ENDIF()
    CGET_BUILD(${ARGV})
    file(WRITE "${BUILD_DIR}/.built" "${Build_Hash}")
  endif ()

  if(NOT ARGS_FINDNAME)
    set(ARGS_FINDNAME "${name}")
  endif()
 
  if (NOT ARGS_NO_FIND_PACKAGE)
    CGET_MESSAGE(3 "Finding ${name} with ${ARGS_CMAKE_VERSION} ${ARGS_FIND_OPTIONS} in ${CMAKE_PREFIX_PATH} ${CMAKE_FIND_LIBRARY_SUFFIXES}")
    find_package(${ARGS_FINDNAME} ${ARGS_CMAKE_VERSION} ${ARGS_FIND_OPTIONS}  )

    IF (${${ARGS_FINDNAME}_FOUND})
      CGET_MESSAGE(1 "Found ${name} ${ARGS_CMAKE_VERSION}")
    ENDIF ()
  endif ()
  CGET_MESSAGE(5 "EXIT CGET_HAS_DEPENDENCY ${ARGV}")
endfunction(CGET_HAS_DEPENDENCY) 
 
