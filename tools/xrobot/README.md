# XRobot Tool Scripts

本目录提供仓库专用的 XRobot CLI 包装脚本，目标是把常用命令固定到本仓库约定的路径上，同时解决“本机未安装 xrobot”时的调用问题。

脚本不会修改构建系统本身；它们只负责：

- 调用全局已安装的 `xrobot` CLI
- 或者在 `tools/xrobot/.venv` 中安装并调用 `xrobot`
- 或者在临时 venv 中调用 `xrobot`

## Scripts

### `invoke_xrobot_cli.ps1`

通用包装器。

- 优先调用 PATH 中已有的 XRobot 命令
- 若未找到，可自动使用 `tools/xrobot/.venv`
- 也可显式切换到临时 venv

常用参数：

- `-Command`
  - 要调用的具体命令，例如 `xrobot_gen_main`
- `-Runner`
  - `auto`
  - `system`
  - `local-venv`
  - `temp-venv`
- `-PackageSpec`
  - 默认为 `xrobot`
  - 如需锁版本，可传 `xrobot==<version>`

示例：

```powershell
.\tools\xrobot\invoke_xrobot_cli.ps1 -Command xrobot_mod_parser -Arguments @('--path', 'Modules\DroneCAN_core')
```

### `generate_main.ps1`

仓库专用入口生成脚本，固定生成目标为 `User/xrobot_main.hpp`，默认配置文件为 `User/xrobot.yaml`。
除调用上游 `xrobot_gen_main` 外，它还会做仓库内后处理：

- 依据 `Modules/*/module.yaml` 纠正生成入口里的模块头文件与类名
- 依据 `User/xrobot.yaml` 直接生成 `User/xrobot_constexpr.hpp`

示例：

```powershell
.\Tools\xrobot\generate_main.ps1
.\Tools\xrobot\generate_main.ps1 -Runner local-venv
.\Tools\xrobot\generate_main.ps1 -Runner temp-venv
.\Tools\xrobot\generate_main.ps1 -Modules DroneCAN_core
```

可选参数：

- `-Config`
  - 默认 `User/xrobot.yaml`
- `-Output`
  - 默认 `User/xrobot_main.hpp`
- `-ConstexprOutput`
  - 默认与 `User/xrobot_main.hpp` 同目录的 `User/xrobot_constexpr.hpp`
- `-Modules`
  - 显式指定参与生成的模块名
- `-HardwareVariable`
  - 传给 `xrobot_gen_main --hw`，默认 `hw`

### `sync_xrobot_modules.ps1`

仓库专用模块同步脚本，对应 `xrobot_init_mod`。

示例：

```powershell
.\tools\xrobot\sync_xrobot_modules.ps1
.\tools\xrobot\sync_xrobot_modules.ps1 -Runner local-venv
```

默认约定：

- `Modules/modules.yaml` 为模块仓库清单
- `Modules/sources.yaml` 为可选源索引
- `Modules/` 为模块拉取目录

如果 `Modules/modules.yaml` 不存在，`xrobot_init_mod` 会按上游行为生成模板文件。

如果 `Modules/sources.yaml` 不存在，脚本会省略 `--sources` 参数，让 `xrobot_init_mod` 使用上游默认行为。

## Recommended Workflow

1. 首次执行 `.\Tools\xrobot\sync_xrobot_modules.ps1`，必要时让 XRobot 先生成 `Modules/modules.yaml` 模板
2. 维护 `Modules/modules.yaml`
3. 如需官方源以外的模块源，再维护 `Modules/sources.yaml`
4. 运行：

```powershell
.\Tools\xrobot\sync_xrobot_modules.ps1
```

5. 维护 `User/xrobot.yaml`
6. 运行：

```powershell
.\Tools\xrobot\generate_main.ps1
```

7. 再使用现有 CMake 预设构建固件

## Notes

- 本仓库当前约定把 `User/xrobot_main.hpp` 和 `User/xrobot_constexpr.hpp` 作为提交产物保留在仓库中，不要求每次构建时动态生成
- 如果你确实需要调用上游一键流程，可直接执行：

```powershell
.\Tools\xrobot\invoke_xrobot_cli.ps1 -Command xrobot_setup
```

- 上游 `xrobot_setup` 可能会同时刷新 `Modules/CMakeLists.txt`。本仓库的日常开发仍建议分开执行模块同步和入口生成，以减少对现有构建接线的干扰

## Fixed Entry Points

为了后续在 `User/CMakeLists.txt` 中挂显式 regenerate target，本仓库约定以下固定入口：

- `Tools/xrobot/generate_main.ps1`
- `Tools/xrobot/README.md`

仓库当前实际目录沿用已有的小写 `tools/`。在当前 Windows 开发环境中，`Tools/` 与 `tools/` 指向同一目录，因此上述入口可以直接使用。
