# DroneCAN H7 Migration Log

日期：2026-04-30

目标工程：`D:\Codes\STM32\XRobot_MC02_DroneCAN`

目标：将 H7 工程从旧 `DroneCAN_*` feature 模块布局迁移到 XRobot 标准模块接入方式：

- 保留 `dronecan_core` 作为 DroneCAN 运行时核心。
- 使用 `dronecan_dsdl` 作为由 DSDL 工具生成的 facade 模块。
- `User/xrobot.yaml` 只实例化 `dronecan_dsdl`。
- DroneCAN 模块以 Git submodule 形式接入工程。

## Initial State

- 用户已在 H7 工程根目录执行 `git init`。
- 原 `Modules/` 中存在旧 feature 模块：
  - `DroneCAN_core`
  - `DroneCAN_heartbeat`
  - `DroneCAN_dynamic_node_id`
  - `DroneCAN_esc_raw_command`
  - `DroneCAN_esc_status`
- `User/xrobot.yaml` 原先实例化旧 `DroneCAN_core` feature 聚合模块。
- `Board/board.hpp` 和 `Board/board.cpp` 已注册 `can1`、`fdcan1`、`dronecan_bus`、`timebase`。
- H7 当前 CAN1/FDCAN1 板级配置保持为 1 Mbit/s。

## Migration Operations

1. 将旧 `DroneCAN_*` feature 模块移出 `Modules/`，避免被 XRobot/CMake 自动扫描并编译。

   备份目录：

   `D:\Codes\STM32\XRobot_MC02_DroneCAN\Modules_backup_dronecan_feature_20260430_185710`

2. 以 Git submodule 标准接入新模块：

   ```powershell
   git submodule add https://github.com/CaFeZn/dronecan_core.git Modules/dronecan_core
   git submodule add https://github.com/CaFeZn/dronecan_dsdl.git Modules/dronecan_dsdl
   ```

   已有 `libxr` 目录也按 `.gitmodules` 中的声明整理为 submodule gitlink：

   ```powershell
   git submodule add --force https://github.com/CaFeZn/libxr.git libxr
   git submodule absorbgitdirs -- libxr Modules/dronecan_core Modules/dronecan_dsdl
   ```

3. 记录当前 submodule 版本：

   - `libxr`: `f0fcff1b321817f2ef15fc7fcd1369e389d1f51f`
   - `Modules/dronecan_core`: `0c6946674570d8fb27941b0a459cd0edc1d8e815`
   - `Modules/dronecan_dsdl`: `ee26fc5d87606236b61743e1d6d2d874fe127be8`

4. 更新模块索引：

   - `Modules/modules.yaml` 只保留 `CaFeZn/dronecan_core@main` 和 `CaFeZn/dronecan_dsdl@main`。
   - `Modules/index.yaml` 只声明两个新模块仓库。
   - `Modules/sources.yaml` 改为相对路径 `Modules/index.yaml`。

5. 更新 `User/xrobot.yaml`：

   - 保留 `DroneCANNodeId = 42`。
   - 保留 `DroneCANNodeStatusPeriodMs = 1000`。
   - 删除旧 feature 模块专用参数：ESC 数量、heartbeat 周期、dynamic node id 开关、poller alias 等。
   - 将应用模块改为 `dronecan_dsdl`，CAN alias 使用 `can1`，timebase alias 使用 `timebase`，节点名为 `org.libxr.h7.dronecan`。

6. 新增/更新文档：

   - `Modules/README.md`
   - `Modules/dronecan_module_layout.md`
   - `Docs/DroneCAN_H7_Migration_Log.md`

7. 新增 `.gitignore`，忽略 `build/`、`Modules_backup*/` 和 `tools/xrobot/.venv/` 等本地生成或备份内容。

8. 新增 H7 本地 SLCAN 探测脚本：

   - `tools/debug_slcan_no_f_probe.py`
   - 默认端口：`COM9`
   - 默认串口波特率：`115200`
   - 默认 CAN bitrate：`1000000`
   - 脚本会跳过部分 SLCAN 适配器不支持的 `F` 命令。

   当前串口枚举结果：

   - `COM9`: STMicroelectronics Virtual COM Port，SLCAN 可正常 open。
   - `COM17`: USB 串行设备，尝试 SLCAN open 时返回 ACK timeout。

   预烧录探测结果：

   ```text
   python tools\debug_slcan_no_f_probe.py --port COM9 --baudrate 115200 --bitrate 1000000 --node-id 120 --observe-sec 2
   NODE_STATUS_COUNTS {}
   ENTRY_COUNT 0
   ```

   说明：SLCAN 适配器可用；由于新固件尚未通过 DAP 烧录，当前未发现 DroneCAN 节点。

9. 重新生成 XRobot 应用入口：

   ```powershell
   .\tools\xrobot\generate_main.ps1
   ```

   生成结果：

   - `User/xrobot_main.hpp` 包含 `#include "dronecan_dsdl.hpp"`。
   - `User/xrobot_main.hpp` 实例化 `static DroneCANDsdl dronecan_dsdl(...)`。
   - `User/xrobot_constexpr.hpp` 只保留 `DroneCANNodeId` 和 `DroneCANNodeStatusPeriodMs`。

10. 重新配置 CMake：

   ```powershell
   cmake --preset Debug
   ```

   配置结果：

   - `[XRobot] Including module: dronecan_core`
   - `[XRobot] Including module: dronecan_dsdl`
   - 旧 `DroneCAN_*` feature 模块不再进入构建图。

11. 编译 Debug 固件：

    ```powershell
    cmake --build --preset Debug
    ```

    编译结果：通过。

    产物：

    - `build/Debug/XRobot_MC02_DroneCAN.elf`

    链接后资源占用：

    - FLASH: `136084 B / 1 MB`
    - DTCMRAM: `17704 B / 128 KB`

12. 烧录后第一次 SLCAN 探测未发现节点。OpenOCD 暂停读取 FDCAN1 状态发现：

    - CPU 正在 `LibXR::Thread::Sleep()` 中运行，应用未卡死。
    - FDCAN1 `CCCR=0x1001`，处于 init/bus-off 相关状态。
    - FDCAN1 `ECR` 的 TX error 已累积到高值，说明节点已经尝试发送 NodeStatus，但总线未收到 ACK。

    排查板级初始化后发现 `POWER_5V` 在 `MX_GPIO_Init()` 中默认拉高，但 `Board::Init()` 将其作为 `led2` 写成低电平。为避免关闭外部 5V 供电或 CAN 收发器供电，已改为：

    ```cpp
    led2.Write(true);
    ```

13. 第二次测试仍未发现节点，FDCAN1 仍表现为 TX error/bus-off。原 CAN1 时序为 120 MHz / 24 / 5TQ = 1 Mbit/s，时间量子过少，实际线缆和适配器下同步裕量不足。保持 bitrate 为 1 Mbit/s，改为 20TQ/80% sample point：

    ```cpp
    can_config.bit_timing.brp = 6U;
    can_config.bit_timing.prop_seg = 8U;
    can_config.bit_timing.phase_seg1 = 7U;
    can_config.bit_timing.phase_seg2 = 4U;
    can_config.bit_timing.sjw = 4U;
    ```

    计算：120 MHz / 6 / (1 + 8 + 7 + 4) = 1 Mbit/s。

14. 20TQ/1 Mbit/s 后仍未发现节点，FDCAN1 仍为 TX error/bus-off。为排除总线速率不匹配，将 H7 CAN1 和 SLCAN 探测默认值临时切到 500 kbit/s：

    ```cpp
    can_config.bitrate = 500000U;
    can_config.bit_timing.brp = 12U;
    ```

    计算：120 MHz / 12 / (1 + 8 + 7 + 4) = 500 kbit/s。

15. 500 kbit/s 后仍未发现节点，FDCAN1 仍 bus-off。为验证板载接口标签和 MCU FDCAN 实例是否一一对应，临时将 XRobot `can1` alias 绑定到底层 `hfdcan2`，并同步把全局滤波和中断通知切到 `hfdcan2`。

16. FDCAN2 + 500 kbit/s 测试仍未发现节点，FDCAN2 同样进入 TX error/bus-off，说明问题不在 FDCAN1/FDCAN2 选择或 1M/500k 速率本身，而是当前接线/终端/收发器供电或 standby 等物理层没有 ACK。临时测试结束后，工程主线恢复为：

    - `hfdcan1`
    - XRobot alias: `can1`
    - CAN bitrate: `1000000`
    - bit timing: `BRP=6, TSEG1=15, TSEG2=4, SJW=4`
    - SLCAN 探测脚本默认 bitrate: `1000000`

## Verification

已完成：

- `tools\xrobot\generate_main.ps1`
- `cmake --preset Debug`
- `cmake --build --preset Debug`
- `openocd -f openocd_stm32h723_swd.cfg -c "program build/Debug/XRobot_MC02_DroneCAN.elf verify reset exit"`
- SLCAN adapter open: `COM9`, `115200`, `1 Mbit/s`

最终烧录结果：

```text
** Programming Finished **
** Verify Started **
** Verified OK **
** Resetting Target **
```

当前固件：

- `build/Debug/XRobot_MC02_DroneCAN.elf`
- DroneCAN node id: `42`
- DroneCAN node name: `org.libxr.h7.dronecan`
- XRobot CAN alias: `can1`
- MCU instance: `hfdcan1`
- CAN bitrate: `1 Mbit/s`

当前未完成：

1. SLCAN 未探测到节点：

   ```text
   NODE_STATUS_COUNTS {}
   ENTRY_COUNT 0
   ```

2. OpenOCD 读 FDCAN 状态显示节点已经尝试发送，但没有收到 ACK，随后进入 bus-off/init：

   - `CCCR=0x1001`
   - `ECR` 中 TX error counter 累积到高值

结论：

- XRobot 模块迁移、生成入口、编译、DAP 烧录均通过。
- 应用主循环在运行，DroneCAN 节点会尝试发布 NodeStatus。
- 当前问题集中在 CAN 物理层没有 ACK，不是 XRobot 入口或 DSDL 模块未运行。
- 2026-04-30 19:31 复测：重新烧录 verify 通过；先打开 SLCAN，再 `reset halt`/`resume` H7，仍未发现节点。
- `COM17` 已按 115200、230400、460800、921600、1000000、2000000 测试，均不是可用 SLCAN；当前可用 SLCAN 端口仍为 `COM9`。
- 因未达到“CAN1 上发现 node 42 / org.libxr.h7.dronecan”的调试通过条件，本次未执行 git commit。

下一步硬件检查：

- 确认 SLCAN 的 CANH/CANL/GND 接到 H7 实际 CAN1 收发器输出，而不是 MCU TX/RX 逻辑引脚。
- 确认 CANH/CANL 没有接反。
- 确认总线两端终端电阻有效，CANH-CANL 静态电阻约为 60 ohm。
- 确认 H7 板载 CAN 收发器供电正常，standby/silent 引脚处于 normal mode。
- 若板上“CAN1”接口实际接到 FDCAN2/FDCAN3，需要把 `Board::Init()` 中的底层实例从 `hfdcan1` 切到对应实例后再测。
- 调试时应先打开 SLCAN，再 reset H7，避免 H7 在没有 ACK 的情况下先进入 bus-off。
