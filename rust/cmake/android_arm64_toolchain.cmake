# Wrapper toolchain to force Android ABI/API before loading the NDK toolchain

if(DEFINED ENV{ANDROID_NDK})
  set(ANDROID_NDK "$ENV{ANDROID_NDK}" CACHE PATH "Android NDK root" FORCE)
elseif(DEFINED ENV{ANDROID_NDK_HOME})
  set(ANDROID_NDK "$ENV{ANDROID_NDK_HOME}" CACHE PATH "Android NDK root" FORCE)
elseif(DEFINED ENV{ANDROID_NDK_ROOT})
  set(ANDROID_NDK "$ENV{ANDROID_NDK_ROOT}" CACHE PATH "Android NDK root" FORCE)
endif()

# Force arch and API level early so the NDK toolchain uses aarch64
set(ANDROID_ABI "arm64-v8a" CACHE STRING "Android ABI" FORCE)
set(ANDROID_PLATFORM "23" CACHE STRING "Android API level" FORCE)

# Optional CMake hints for completeness
set(CMAKE_SYSTEM_NAME "Android" CACHE STRING "" FORCE)
set(CMAKE_SYSTEM_PROCESSOR "aarch64" CACHE STRING "" FORCE)
set(CMAKE_SYSTEM_VERSION "23" CACHE STRING "" FORCE)

include("${ANDROID_NDK}/build/cmake/android.toolchain.cmake")
