find_package(Python REQUIRED COMPONENTS Interpreter)

# The build environment is prepared by tools/bootstrap-build.sh.
# CMake must not install Python packages or modify Git configuration.
execute_process(
  COMMAND ${Python_EXECUTABLE} -m splat --version
  OUTPUT_VARIABLE SPLAT_VERSION_OUTPUT
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE SPLAT_VERSION_RESULT
)

if(NOT SPLAT_VERSION_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Splat is not available in the selected Python environment.\n"
    "Run tools/bootstrap-build.sh first."
  )
endif()

if(NOT SPLAT_VERSION_OUTPUT MATCHES "splat 0\\.41\\.0")
  message(FATAL_ERROR
    "Incorrect Splat version.\n"
    "Expected: splat 0.41.0\n"
    "Found: ${SPLAT_VERSION_OUTPUT}"
  )
endif()

# Build Torch
execute_process(
  COMMAND ${CMAKE_COMMAND}
          -S ${TOOLS_DIR}/Torch
          -B ${TOOLS_DIR}/Torch/build
          -G Ninja
          -DCMAKE_BUILD_TYPE=Release
          -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE TORCH_CONFIGURE_RESULT
)

if(NOT TORCH_CONFIGURE_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Failed to configure Torch (exit code ${TORCH_CONFIGURE_RESULT})."
  )
endif()

execute_process(
  COMMAND ${CMAKE_COMMAND} --build ${TOOLS_DIR}/Torch/build
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE TORCH_BUILD_RESULT
)

if(NOT TORCH_BUILD_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Failed to build Torch (exit code ${TORCH_BUILD_RESULT})."
  )
endif()

# Run Splat
execute_process(
  COMMAND ${Python_EXECUTABLE} -m splat split --verbose ${SPLAT_CONFIG}
  OUTPUT_FILE ${CMAKE_BINARY_DIR}/splat.log
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE SPLAT_SPLIT_RESULT
)

if(NOT SPLAT_SPLIT_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Splat failed to split the ROM (exit code ${SPLAT_SPLIT_RESULT}).\n"
    "See ${CMAKE_BINARY_DIR}/splat.log for details."
  )
endif()

# Run Torch Extract assets as source code files
execute_process(
  COMMAND ${TORCH} code ${BASEROM_UNCOMPRESSED} -v
  OUTPUT_FILE ${CMAKE_BINARY_DIR}/torch.log
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE TORCH_CODE_RESULT
)

if(NOT TORCH_CODE_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Torch code extraction failed (exit code ${TORCH_CODE_RESULT}).\n"
    "See ${CMAKE_BINARY_DIR}/torch.log for details."
  )
endif()

# Extract header files
execute_process(
  COMMAND ${TORCH} header ${BASEROM_UNCOMPRESSED}
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE TORCH_HEADER_RESULT
)

if(NOT TORCH_HEADER_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Torch header extraction failed (exit code ${TORCH_HEADER_RESULT})."
  )
endif()

# Extract some data into humanly-readable formats (such as image data to .png)
execute_process(
  COMMAND ${TORCH} modding export ${BASEROM_UNCOMPRESSED}
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE TORCH_MODDING_RESULT
)

if(NOT TORCH_MODDING_RESULT EQUAL 0)
  message(FATAL_ERROR
    "Torch modding export failed (exit code ${TORCH_MODDING_RESULT})."
  )
endif()

set(MIPS_BINUTILS_PREFIX mips-linux-gnu-)

# Install IDO compilers
execute_process(
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/cmake/IDO.cmake
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  RESULT_VARIABLE IDO_SETUP_RESULT
)

if(NOT IDO_SETUP_RESULT EQUAL 0)
  message(FATAL_ERROR
    "IDO compiler setup failed (exit code ${IDO_SETUP_RESULT})."
  )
endif()

set(TOOLCHAIN_ASM_COMPILER_EXE ${MIPS_BINUTILS_PREFIX}as)
find_program(CMAKE_ASM_COMPILER ${TOOLCHAIN_ASM_COMPILER_EXE} HINTS "/usr/bin" REQUIRED)
set(CMAKE_ASM_COMPILE_OBJECT "<CMAKE_ASM_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -o <OBJECT> <SOURCE>")

set(CMAKE_C_COMPILER_LAUNCHER
    ${Python_EXECUTABLE}
    ${TOOLS_DIR}/asm-processor/build.py
    --base-dir
    ${CMAKE_SOURCE_DIR})
set(TOOLCHAIN_C_COMPILER_EXE "${TOOLS_DIR}/ido/linux/7.1/cc")

if(NOT EXISTS "${TOOLCHAIN_C_COMPILER_EXE}")
  message(FATAL_ERROR
    "IDO 7.1 compiler was not found at:\n"
    "${TOOLCHAIN_C_COMPILER_EXE}"
  )
endif()
set(CMAKE_C_COMPILER
    ${TOOLCHAIN_C_COMPILER_EXE}
    --
    ${CMAKE_ASM_COMPILER}
    -I${CMAKE_SOURCE_DIR}/include
    -march=vr4300
    -EB
    --)
set(CMAKE_C_COMPILER_WORKS TRUE)

set(TOOLCHAIN_LINKER_EXE ${MIPS_BINUTILS_PREFIX}ld)
find_program(CMAKE_LINKER ${TOOLCHAIN_LINKER_EXE} HINTS "/usr/bin" REQUIRED)
set(CMAKE_C_LINK_EXECUTABLE "<CMAKE_LINKER> <LINK_FLAGS> <OBJECTS> -o <TARGET>")

set(TOOLCHAIN_OBJCOPY_EXE ${MIPS_BINUTILS_PREFIX}objcopy)
find_program(CMAKE_OBJCOPY ${TOOLCHAIN_OBJCOPY_EXE} HINTS "/usr/bin" REQUIRED)
