# DroneCAN Module Layout / DroneCAN 模块布局

## Current Mainline / 当前主线

H7 工程的 DroneCAN 主线由两个 XRobot 模块组成。

The H7 project uses two XRobot modules for DroneCAN.

- `dronecan_core`: runtime-only module. It provides DroneCAN node, transfer, frame and transport support.
- `dronecan_dsdl`: generated facade module. It contains one generated header per configured DSDL type, plus a facade class used by XRobot.

旧布局中的 `DroneCAN_heartbeat`、`DroneCAN_dynamic_node_id`、`DroneCAN_esc_raw_command`、`DroneCAN_esc_status` 已从主线移除。

The old `DroneCAN_heartbeat`, `DroneCAN_dynamic_node_id`,
`DroneCAN_esc_raw_command`, and `DroneCAN_esc_status` feature modules have been
removed from the active mainline.

## XRobot Configuration / XRobot 配置

应用入口由 `User/xrobot.yaml` 描述，并通过 `tools/xrobot/generate_main.ps1` 生成。

The application entry is described by `User/xrobot.yaml` and generated with
`tools/xrobot/generate_main.ps1`.

```yaml
modules:
  - id: dronecan_dsdl
    name: dronecan_dsdl
    constructor_args:
      node_id:
        constexpr: DroneCANNodeId
      can_alias: can1
      timebase_alias: timebase
      node_name: org.libxr.h7.dronecan
      node_status_period_ms:
        constexpr: DroneCANNodeStatusPeriodMs
```

生成结果应包含 `#include "dronecan_dsdl.hpp"` 和 `static DroneCANDsdl dronecan_dsdl(...)`。

The generated result should include `#include "dronecan_dsdl.hpp"` and
`static DroneCANDsdl dronecan_dsdl(...)`.

## DSDL Generation / DSDL 生成

`Modules/dronecan_dsdl/module.yaml` 中的 `dsdl` 列表决定生成哪些 DSDL 头文件。每个 DSDL 类型生成一个独立头文件；未显式填写 `header` 时使用默认命名。

The `dsdl` list in `Modules/dronecan_dsdl/module.yaml` decides which generated
headers are available. Each DSDL type maps to one generated header. If `header`
is omitted, the generator uses the default header name.

当前默认包含：

The current default set is:

- `uavcan.equipment.esc.RawCommand`
- `uavcan.equipment.esc.Status`
- `uavcan.protocol.dynamic_node_id.Allocation`

如果要接入自定义 DSDL，应在 `dronecan_dsdl` 模块仓库内更新 DSDL 源和 `module.yaml`，重新运行生成器，然后在本工程更新 submodule 指针。

For custom DSDL, update the DSDL source and `module.yaml` in the
`dronecan_dsdl` module repository, regenerate the facade, then update the
submodule pointer in this project.
