# XRobot MC02 DroneCAN H7 Example

This repository is an STM32H723 XRobot example project for DroneCAN over FDCAN1.

## What this example contains

- STM32H723 CubeMX/CMake board project
- XRobot generated application entry under `User/`
- `libxr` as a git submodule
- DroneCAN modules as git submodules:
  - `Modules/dronecan_core`
  - `Modules/dronecan_dsdl`
- FDCAN1 configured for classic DroneCAN/SLCAN regression testing
- `User/dronecan_example.hpp` demonstrates both APIs:
  - normal mode receives `RawCommand` with typed callbacks and sends `Status`
    with `DroneCANDsdl::PublishUavcanEquipmentEscStatus()`
  - Topic mode subscribes `/dronecan/uavcan/equipment/esc/Status` and publishes
    `/dronecan/tx/uavcan/equipment/esc/RawCommand`

## Hardware baseline

- MCU: STM32H723
- CAN: FDCAN1
- Debug: CMSIS-DAP over SWD
- SLCAN test port used during validation: `COM9`
- SLCAN speed command: `S8`

## Build

```powershell
cmake -G Ninja `
  -DCMAKE_MAKE_PROGRAM=D:/ST/STM32CubeCLT_1.19.0/Ninja/bin/ninja.exe `
  -DCMAKE_BUILD_TYPE=Debug `
  -DCMAKE_TOOLCHAIN_FILE=D:/Codes/STM32/XRobot_MC02_DroneCAN/cmake/gcc-arm-none-eabi.cmake `
  -S . `
  -B build/Debug

cmake --build build/Debug --parallel
```

## Flash

```powershell
openocd -f openocd_stm32h723_swd.cfg -c "program {build/Debug/XRobot_MC02_DroneCAN.elf} verify reset exit"
```

## SLCAN regression notes

The validated baseline checks:

- 1 Hz DroneCAN node status heartbeat
- `GetNodeInfo` request/response
- generated DSDL decode callback path for ESC `RawCommand`

This repository is intended as an integration example. Reusable DroneCAN logic lives in the module repositories, not in board-specific files.
