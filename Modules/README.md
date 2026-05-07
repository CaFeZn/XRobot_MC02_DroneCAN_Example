# XRobot DroneCAN Modules

本工程的 DroneCAN 接入采用 XRobot 标准模块布局。

This project uses the standard XRobot module layout for DroneCAN integration.

- `Modules/dronecan_core`: DroneCAN 运行时核心，只提供节点、传输和调度基础能力。
- `Modules/dronecan_dsdl`: 由 DSDL 工具生成的 facade 模块，按 `module.yaml` 中的 DSDL 类型生成对应头文件并接入工程。
- 旧的 `DroneCAN_*` feature 模块不再作为主线使用，迁移时已移动到根目录备份目录。

The active modules are `dronecan_core` and `dronecan_dsdl`. The previous
`DroneCAN_*` feature modules are kept only as backup material and are not built
from `Modules/`.

## Module Source

模块索引由当前目录下的 YAML 文件描述。

Module discovery is described by the YAML files in this directory.

- `sources.yaml`: 指向本地 `Modules/index.yaml`，避免使用机器相关的绝对路径。
- `index.yaml`: 声明可用模块仓库地址。
- `modules.yaml`: 声明当前工程实际需要拉取和启用的模块。

## Submodule Rule

在正式工程中，DroneCAN 模块应作为 Git submodule 固定版本。

In a production project, DroneCAN modules should be pinned as Git submodules.

```powershell
git submodule add https://github.com/CaFeZn/dronecan_core.git Modules/dronecan_core
git submodule add https://github.com/CaFeZn/dronecan_dsdl.git Modules/dronecan_dsdl
git submodule update --init --recursive
```

应用侧只在 `User/xrobot.yaml` 中引用 `dronecan_dsdl`，不要再直接实例化旧 feature 模块。

The application should instantiate `dronecan_dsdl` from `User/xrobot.yaml`; the
old feature modules should not be instantiated directly.
