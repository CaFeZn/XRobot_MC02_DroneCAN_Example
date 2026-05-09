# XRobot MC02 DroneCAN H7 例程 / Example

本仓库是一个基于 STM32H723 的 XRobot 例程工程，用于演示通过 FDCAN1 运行
DroneCAN。

This repository is an STM32H723 XRobot example project for running DroneCAN over
FDCAN1.

## 例程内容 / What This Example Contains

本例程包含：

- STM32H723 CubeMX/CMake 板级工程
- `User/` 下的 XRobot 生成应用入口
- 以 Git submodule 接入的 `libxr`
- 以 Git submodule 接入的 DroneCAN 模块：
  - `Modules/dronecan_core`
  - `Modules/dronecan_dsdl`
- 用于经典 DroneCAN/SLCAN 回归测试的 FDCAN1 配置
- `User/dronecan_example.hpp` 同时演示两种 API：
  - 普通模式：通过类型化 callback 接收 `RawCommand`，并通过
    `DroneCANDsdl::PublishUavcanEquipmentEscStatus()` 发送 `Status`
  - Topic 模式：订阅 `/dronecan/uavcan/equipment/esc/Status`，并发布
    `/dronecan/tx/uavcan/equipment/esc/RawCommand`

This example contains:

- STM32H723 CubeMX/CMake board project
- XRobot generated application entry under `User/`
- `libxr` as a Git submodule
- DroneCAN modules as Git submodules:
  - `Modules/dronecan_core`
  - `Modules/dronecan_dsdl`
- FDCAN1 configured for classic DroneCAN/SLCAN regression testing
- `User/dronecan_example.hpp` demonstrates both APIs:
  - normal mode receives `RawCommand` with typed callbacks and sends `Status`
    with `DroneCANDsdl::PublishUavcanEquipmentEscStatus()`
  - Topic mode subscribes `/dronecan/uavcan/equipment/esc/Status` and publishes
    `/dronecan/tx/uavcan/equipment/esc/RawCommand`

## 硬件基线 / Hardware Baseline

- MCU：STM32H723
- CAN：FDCAN1
- 调试接口：CMSIS-DAP over SWD
- 验证时使用的 SLCAN 测试端口：`COM9`
- SLCAN 速率命令：`S8`

- MCU: STM32H723
- CAN: FDCAN1
- Debug: CMSIS-DAP over SWD
- SLCAN test port used during validation: `COM9`
- SLCAN speed command: `S8`

## 构建 / Build

使用 Ninja 和 ARM GCC 工具链配置 Debug 构建目录：

Configure the Debug build directory with Ninja and the ARM GCC toolchain:

```powershell
cmake -G Ninja `
  -DCMAKE_MAKE_PROGRAM=D:/ST/STM32CubeCLT_1.19.0/Ninja/bin/ninja.exe `
  -DCMAKE_BUILD_TYPE=Debug `
  -DCMAKE_TOOLCHAIN_FILE=D:/Codes/STM32/XRobot_MC02_DroneCAN/cmake/gcc-arm-none-eabi.cmake `
  -S . `
  -B build/Debug

cmake --build build/Debug --parallel
```

## 烧录 / Flash

通过 OpenOCD 烧录并复位目标板：

Flash and reset the target with OpenOCD:

```powershell
openocd -f openocd_stm32h723_swd.cfg -c "program {build/Debug/XRobot_MC02_DroneCAN.elf} verify reset exit"
```

## SLCAN 回归说明 / SLCAN Regression Notes

已验证的基线检查项：

- 1 Hz DroneCAN 节点状态心跳
- `GetNodeInfo` 请求/响应
- ESC `RawCommand` 的生成 DSDL 解码 callback 路径

The validated baseline checks:

- 1 Hz DroneCAN node status heartbeat
- `GetNodeInfo` request/response
- generated DSDL decode callback path for ESC `RawCommand`

本仓库定位为集成例程。可复用的 DroneCAN 逻辑保存在模块仓库中，不放在板级工程文件里。

This repository is intended as an integration example. Reusable DroneCAN logic
lives in the module repositories, not in board-specific files.
