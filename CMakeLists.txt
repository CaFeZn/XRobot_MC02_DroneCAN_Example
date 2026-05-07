cmake_minimum_required(VERSION 3.22)

#
# This file is generated only once,
# and is not re-generated if converter is called multiple times.
#
# User is free to modify the file as much as necessary
#

# Setup compiler settings
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)


# Define the build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

# Set the project name
set(CMAKE_PROJECT_NAME XRobot_MC02_DroneCAN)

# Enable compile command to ease indexing with e.g. clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# Core project settings
project(${CMAKE_PROJECT_NAME})
message("Build type: " ${CMAKE_BUILD_TYPE})

# Enable CMake support for ASM, C and C++ languages
enable_language(C CXX ASM)

# Create an executable object type
add_executable(${CMAKE_PROJECT_NAME})

set(LIBXR_DIR "${CMAKE_CURRENT_LIST_DIR}/libxr" CACHE PATH "Path to LibXR source tree")
set(LIBXR_SYSTEM None CACHE STRING "" FORCE)
set(LIBXR_DRIVER "" CACHE STRING "" FORCE)
set(LIBXR_TEST_BUILD False CACHE BOOL "" FORCE)
set(LIBXR_ENABLE_DRONECAN ON CACHE BOOL "" FORCE)
set(XROBOT_MODULES_DIR "${CMAKE_CURRENT_LIST_DIR}/Modules" CACHE PATH "" FORCE)

# Add STM32CubeMX generated sources
add_subdirectory(cmake/stm32cubemx)
add_subdirectory("${LIBXR_DIR}" "${CMAKE_BINARY_DIR}/libxr_build")

target_sources(xr PRIVATE
    "${LIBXR_DIR}/driver/st/stm32_atomic_shim.c"
    "${LIBXR_DIR}/driver/st/stm32_canfd.cpp"
    "${LIBXR_DIR}/driver/st/stm32_gpio.cpp"
)

target_include_directories(xr PUBLIC
    "${LIBXR_DIR}/driver/st"
    Core/Inc
    USB_DEVICE/App
    USB_DEVICE/Target
    Drivers/STM32H7xx_HAL_Driver/Inc
    Drivers/STM32H7xx_HAL_Driver/Inc/Legacy
    Drivers/CMSIS/Device/ST/STM32H7xx/Include
    Drivers/CMSIS/Include
)

target_compile_definitions(xr PUBLIC
    USE_PWR_LDO_SUPPLY
    USE_HAL_DRIVER
    STM32H723xx
)

# Link directories setup
target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined library search paths
)

# Add sources to executable
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    Board/board.cpp
    User/app.cpp
)

# Add include paths
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    Board
    User
)

# Add project symbols (macros)
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
    APP_DAP_MODE=DAP_SWD
)

# Remove wrong libob.a library dependency when using cpp files
list(REMOVE_ITEM CMAKE_C_IMPLICIT_LINK_LIBRARIES ob)

# Add linked libraries
target_link_libraries(${CMAKE_PROJECT_NAME}
    stm32cubemx
    xr

    # Add user defined libraries
)
