# doi-linux-inventory-fix

[![简体中文](https://img.shields.io/badge/Language-简体中文-blue)](README.md)
[![English](https://img.shields.io/badge/Language-English-lightgrey)](README.en.md)

修复 **Day of Infamy（DOI）Windows 客户端与 Linux 专用服务器之间的库存校验消息编号不一致问题**，使客户端库存消息能够进入服务端原生的 Steam 库存校验流程。

插件名称：`doi-linux-inventory-fix`  
插件版本：`0.1.2`  
作者：`SannyonnGonana`

本项目以 SourceMod 插件形式运行，适用于通过 SteamCMD 部署的 DOI Linux **32 位服务端进程**。运行时将 Windows 客户端发送的 `19` 号消息路由到服务端原有的 `20` 号库存消息处理对象，继续使用游戏自身的解析器、处理函数和 Steam 所有权校验。

> **安装前请确认：**服务器已经能够正常运行，SourceMod 与 DHooks 已正确加载，且 BattlEye 实际处于关闭状态。当前插件依赖特定引擎实现，不能保证适用于所有 DOI 服务端版本。

## 目录

- [修复范围与适用条件](#修复范围与适用条件)
- [仓库文件](#仓库文件)
- [安装前准备](#安装前准备)
- [安装步骤](#安装步骤)
- [验证修复是否生效](#验证修复是否生效)
- [管理命令与日志](#管理命令与日志)
- [更新、回滚与卸载](#更新回滚与卸载)
- [常见问题与故障排查](#常见问题与故障排查)
- [从源码编译](#从源码编译)
- [实现原理与版本适配](#实现原理与版本适配)
- [文件完整性校验](#文件完整性校验)
- [反馈问题](#反馈问题)
- [许可](#许可)

## 修复范围与适用条件

在本项目对应的协议差异中，Windows 客户端使用消息编号 `19` 发送库存更新，而 Linux 服务端的原生库存消息编号为 `20`；服务端原有的 `19` 号消息对象是 `CLC_AntiCheatPacket`。插件修正的是消息分发目标。

原有部署记录中，指虎及阵营外观已通过玩家实测。这一记录针对当时部署环境，不代表其他服务端构建、客户端平台或所有库存物品均已测试。

| 项目 | 要求或范围 |
| --- | --- |
| 游戏 | Day of Infamy，游戏目录名为 `doi` |
| 服务端 | Linux 32 位引擎，且符合插件校验的符号、指令及内存布局 |
| 操作系统 | 可以是 64 位 Linux，但必须能正常运行游戏的 32 位服务端及其依赖 |
| 插件框架 | 可在该 DOI 服务端运行的 Metamod:Source、SourceMod |
| 扩展 | DHooks，支持 `DynamicDetour` |
| BattlEye | 必须实际关闭；插件不会替你关闭它 |
| 客户端 | 当前修复针对使用 `19` 号库存消息的 Windows 客户端 |

插件保留 Steam 库存及物品所有权校验，不会发放库存物品或解锁未拥有的内容，也不负责处理 Steam 服务异常、物品归属问题或其他原因导致的外观不可用。

目前仓库没有记录原实测环境的精确游戏 Build ID、Metamod:Source 与 SourceMod 版本，因此不提供未经验证的完整版本兼容列表。Windows 服务端、64 位服务端以及其他游戏不属于当前适配范围。

## 仓库文件

```text
.
├── LICENSE
├── README.md
├── README.en.md
└── addons/
    └── sourcemod/
        ├── plugins/
        │   └── doi-linux-inventory-fix.smx    # 编译后的插件，运行必需
        ├── gamedata/
        │   └── doi-linux-inventory-fix.txt    # 引擎函数符号配置，运行必需
        └── scripting/
            └── doi-linux-inventory-fix.sp     # SourcePawn 源码
```

直接安装时只需 `.smx` 和 gamedata `.txt`；`.sp` 用于审查、修改或自行编译。**只上传 `.smx` 不足以运行插件。**

## 安装前准备

### 1. 确认服务器目录

下文约定：

- `/srv/doi-server`：游戏服务器安装根目录，即包含 `srcds_run` 和 `doi/` 的目录。
- `/tmp/doi-linux-inventory-fix`：本仓库下载或解压后的目录，即包含本 README 和 `addons/` 的目录。

请将示例路径替换为你的实际路径。插件最终应安装到 **`服务器根目录/doi/addons/sourcemod/`**，而不是 `服务器根目录/addons/`。

正常目录结构示例：

```text
/srv/doi-server/
├── srcds_run
└── doi/
    ├── gameinfo.txt
    ├── cfg/
    │   └── server.cfg
    └── addons/
        ├── metamod/
        └── sourcemod/
            ├── plugins/
            ├── gamedata/
            ├── extensions/
            └── logs/
```

### 2. 检查 SourceMod 和 DHooks

尚未安装框架时，先获取适合 DOI 服务端的 Linux 版本，并完成安装：

- [Metamod:Source 官方网站](https://www.sourcemm.net/)
- [SourceMod 官方下载](https://www.sourcemod.net/downloads.php)

在**服务端控制台**依次执行：

```text
meta version
sm version
sm exts list
```

确认 Metamod:Source、SourceMod 能输出版本，并且扩展列表中 DHooks 正常运行，没有加载错误。[DHooks 官方说明](https://wiki.alliedmods.net/DHooks_%28SourceMod_Scripting%29)指出，SourceMod 1.12 及较新的 1.11 构建已包含 DHooks。是否可用仍应以当前服务器的扩展加载状态为准；这不代表本项目已在这些版本上逐一测试。

如果 `sm` 是未知命令，先修复 SourceMod 安装。若 DHooks 加载失败，先查看扩展错误，不要继续排查本插件的库存计数。

### 3. 确认 BattlEye 已关闭

检查当前生效的服务器配置（例如 `doi/cfg/server.cfg`），将 BattlEye 设置为关闭：

```cfg
sv_battleye 0
```

该设置属于游戏服务端配置，并非本插件的配置项。还需检查启动参数、地图配置和 playlist 是否覆盖了它，然后完整重启服务器。可在服务端控制台查询：

```text
sv_battleye
```

**配置值只能作为检查线索。**插件读取引擎的 BattlEye 运行状态；若加载时报 `Requires BattlEye disabled`，说明运行状态仍不符合要求。仅删除 BattlEye 文件夹或修改某份未生效的配置，不能代替运行状态确认。

## 安装步骤

### 第一步：获取文件

推荐从 [GitHub Releases](https://github.com/SannyonnGonana/doi-linux-inventory-fix/releases/latest) 下载 `doi-linux-inventory-fix-v0.1.2-linux.zip`。该安装包只包含运行必需的 `.smx`、对应 gamedata 和 `LICENSE`；解压后直接得到 `addons/`，便于按下述步骤部署。请保持同一发布版本的文件配套使用。

下载同一 Release 中的 `SHA256SUMS.txt` 后，可在 Linux Shell 中校验安装包：

```bash
sha256sum -c SHA256SUMS.txt
```

需要审查源码或自行编译时，可以克隆仓库，或使用 **Code → Download ZIP**。Release 页面自动提供的 `Source code (zip)` 和 `Source code (tar.gz)` 是完整源码快照，普通安装应选择上面的插件安装包。

### 第二步：备份已有版本

首次安装可跳过备份。更新已有插件时，建议停止服务器后备份；如需在线更新，应先按[管理命令](#管理命令与日志)卸载插件。

下面是 **Linux Shell 命令**，使用有权限读写服务器目录的账号执行：

```bash
SERVER_ROOT="/srv/doi-server"
BACKUP_DIR="$SERVER_ROOT/plugin-backups/doi-linux-inventory-fix-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"
if [ -f "$SERVER_ROOT/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx" ]; then
    cp -p "$SERVER_ROOT/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx" "$BACKUP_DIR/"
fi
if [ -f "$SERVER_ROOT/doi/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt" ]; then
    cp -p "$SERVER_ROOT/doi/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt" "$BACKUP_DIR/"
fi
```

### 第三步：上传插件和 gamedata

使用 SFTP、服务器面板文件管理器或 Shell，将文件按以下对应关系上传：

| 仓库中的文件 | 服务器上的目标文件 |
| --- | --- |
| `addons/sourcemod/plugins/doi-linux-inventory-fix.smx` | `/srv/doi-server/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx` |
| `addons/sourcemod/gamedata/doi-linux-inventory-fix.txt` | `/srv/doi-server/doi/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt` |

如果仓库已经解压在服务器上，可以执行：

```bash
SERVER_ROOT="/srv/doi-server"
PLUGIN_SRC="/tmp/doi-linux-inventory-fix"

install -m 0644 "$PLUGIN_SRC/addons/sourcemod/plugins/doi-linux-inventory-fix.smx" \
    "$SERVER_ROOT/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx"
install -m 0644 "$PLUGIN_SRC/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt" \
    "$SERVER_ROOT/doi/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt"
```

上述命令以 SourceMod 已安装、目标目录已存在为前提。文件需可被运行游戏服务器的账号读取，SourceMod 的 `logs/` 目录需可写；`.smx` 和 `.txt` 不需要可执行权限。

注意避免以下目录错误：

- 不要在服务器上创建 `doi/addons/addons/sourcemod/`。
- 不要将整个仓库目录直接放到 `plugins/` 下。
- 不要把 gamedata 放进 `configs/`，也不要修改其文件名。
- 合并 `addons/` 时保留服务器已有文件，不要用本仓库目录替换整个现有 `addons/`。

### 第四步：加载插件

若服务器已停止，启动后 SourceMod 会自动加载 `plugins/` 目录中的插件。

若服务器正在运行，在**服务端控制台**执行：

```text
sm plugins load doi-linux-inventory-fix.smx
sm plugins list
doi-linux-inventory-fix_status
```

如果是通过游戏客户端控制台管理服务器，需要先配置好 RCON，再为上述命令添加 `rcon` 前缀：

```text
rcon sm plugins load doi-linux-inventory-fix.smx
rcon sm plugins list
rcon doi-linux-inventory-fix_status
```

`sm ...` 和状态命令不是 Linux Shell 命令。插件的状态命令注册为服务端命令，不能当作普通聊天命令使用。

如果提示插件已加载，直接查询状态即可，无需再次加载。

### 第五步：确认加载状态

`sm plugins list` 中应出现插件名称，且没有失败状态。状态命令输出示例：

```text
[DLIF] enabled=1 routed=0 received=0 callbacks=0 missing=0
```

这是尚未收到相关库存消息时的正常示例。随后按下一节完成玩家实测。

本插件没有需要填写的独立 `.cfg`，也没有用于启用功能的插件 ConVar。加载成功后自动工作，跨地图保持加载；服务器重启后也会自动加载。无需把 `sm plugins load` 反复写入 `server.cfg`。

## 验证修复是否生效

建议使用**确实拥有待测试库存物品的 Windows 客户端**验证：

1. 插件加载成功后，执行一次 `doi-linux-inventory-fix_status`，记录初始计数。
2. 让测试玩家重新连接服务器，并尝试选择、使用其拥有的库存内容，例如指虎或阵营外观。
3. 再次查询状态，比较 `routed`、`received` 与 `callbacks` 是否增长。
4. 同时确认游戏内物品或外观是否实际生效，并检查 SourceMod 是否报告错误。
5. 切换地图或重启后，再检查插件加载状态并复测。

一次可能的输出如下，具体数值仅作示意：

```text
[DLIF] enabled=1 routed=2 received=2 callbacks=2 missing=0
```

各字段含义：

| 字段 | 含义 | 如何判断 |
| --- | --- | --- |
| `enabled` | 引擎 BattlEye 状态地址有效且其启用标志为关闭时为 `1` | 不是可手动设置的开关，也不是库存校验成功标志 |
| `routed` | 成功将 `19` 号消息查找结果替换为已注册库存消息对象的次数 | 增长说明兼容路由已被触发 |
| `received` | 原生 `ProcessSteamInventoryUpdate` 函数被调用的次数 | 增长说明执行进入原生库存接收流程 |
| `callbacks` | 原生库存结果回调函数被调用的次数 | 增长说明观察到库存结果回调，不代表结果一定有效 |
| `missing` | 进入目标路由分支后，未找到已注册库存消息对象的次数 | 持续增长需检查版本与注册流程 |

**这些计数不是玩家数量，也不是成功解锁数量。**原生接收与回调计数可能包含其他库存处理，三项计数不要求相等，异步回调也可能稍后出现。最终应结合玩家拥有的物品、游戏内实际表现与服务器错误日志判断修复效果。

计数在插件加载期间累计，换图不清零；卸载后重新加载或重启服务器会重新计数。

## 管理命令与日志

### 常用命令

以下均在服务端控制台执行，通过 RCON 使用时添加 `rcon` 前缀。

| 命令 | 用途 |
| --- | --- |
| `sm plugins list` | 查看插件列表与加载状态 |
| `sm exts list` | 查看 DHooks 等扩展的状态 |
| `sm plugins load doi-linux-inventory-fix.smx` | 加载插件 |
| `doi-linux-inventory-fix_status` | 输出运行条件及累计计数 |
| `sm plugins unload doi-linux-inventory-fix.smx` | 卸载插件并移除其 hooks |

### 日志位置

插件日志：

```text
doi/addons/sourcemod/logs/doi-linux-inventory-fix.log
```

在 Linux Shell 中实时查看：

```bash
tail -f /srv/doi-server/doi/addons/sourcemod/logs/doi-linux-inventory-fix.log
```

日志行示例：

```text
[DLIF] route_windows19_to_inventory20 routed=1 received=0 callbacks=0 missing=0
```

| 阶段标记 | 含义 |
| --- | --- |
| `loaded` | 插件初始化并挂接成功 |
| `map_start` | 地图开始时记录当前计数 |
| `route_windows19_to_inventory20` | 执行了兼容路由 |
| `native_inventory_receive` | 进入原生库存接收函数 |
| `native_result_processed` | 原生库存结果回调执行完毕 |
| `inventory_message_missing` | 未找到已注册的库存消息对象 |
| `unloaded` | 插件结束时记录当前计数 |

为减少日志量，每次加载期间只记录前 8 次路由、前 8 次接收、前 16 次结果回调，以及前 3 次缺失事件。达到上限后计数仍继续增长，可通过状态命令查询。

该插件日志只写入阶段与计数，不记录玩家账号、凭证或库存内容。SourceMod 的加载异常另行查看 `doi/addons/sourcemod/logs/errors_*.log` 和服务端控制台；仅看到 `unloaded` 日志不能证明此前加载成功。

## 更新、回滚与卸载

### 更新插件

1. 停止服务器，或先执行卸载命令。
2. 备份原 `.smx` 和 gamedata `.txt`。
3. 替换为同一新版本的两个文件。
4. 启动服务器，或执行加载命令。
5. 查询状态并进行一次玩家库存验证。

仅覆盖磁盘上的 `.smx` 不会替换已经加载在内存中的插件，必须重新加载或重启。

若同时更新了游戏服务端，引擎符号、指令或布局可能改变。更新后应重新检查加载结果；自行编译同一份源码不能修复引擎适配差异。

### 回滚

停止服务器或卸载插件后，将备份的 `.smx` 与 gamedata `.txt` 一起恢复到原位置，再启动或加载。旧插件仍要求当前引擎符合其校验条件；游戏本体更新后，回滚插件未必能恢复兼容性。

### 暂时停用与彻底卸载

在服务端控制台执行：

```text
sm plugins unload doi-linux-inventory-fix.smx
```

该操作仅停止当前已加载实例。要防止下次启动自动加载，需将 `.smx` 移出自动加载位置，例如在 **Linux Shell** 中执行：

```bash
SERVER_ROOT="/srv/doi-server"
mkdir -p "$SERVER_ROOT/doi/addons/sourcemod/plugins/disabled"
mv "$SERVER_ROOT/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx" \
    "$SERVER_ROOT/doi/addons/sourcemod/plugins/disabled/doi-linux-inventory-fix.smx"
```

彻底卸载时，可在卸载插件后删除对应 `.smx`、gamedata `.txt` 和可选的 `.sp` 源文件；日志可保留用于排查。恢复启用时，将 `.smx` 放回 `plugins/` 并加载，同时确认对应 gamedata 仍存在。

## 常见问题与故障排查

| 现象或错误信息 | 可能原因与处理方法 |
| --- | --- |
| `sm` / `meta` 是未知命令 | 框架未正确加载，或命令输在了 Linux Shell；先在服务端控制台验证 Metamod:Source 和 SourceMod |
| 提示必需的 `dhooks` 扩展未运行，或 DHooks native 缺失 | 用 `sm exts list` 检查扩展错误，确认安装包与 SourceMod、游戏引擎和进程架构匹配 |
| `DOI Linux 32-bit only` | 检查是否误装到其他游戏；此错误在代码中由游戏目录名检查触发，并不等于完整检测了系统或进程位数 |
| `Missing verified gamedata` | 检查 `gamedata/doi-linux-inventory-fix.txt` 是否存在、文件名是否正确、是否可读，并查看 SourceMod 对 gamedata 的解析错误 |
| `Unrecognized engine symbols` | 一个或多个必要符号无法解析；核对 gamedata 和游戏版本，若文件配套且完整则需重新适配引擎 |
| `Engine build differs from the audited 19/20 protocol` | 函数指令或消息编号实现与已核对版本不符；需要审查对应引擎后更新适配 |
| `Unexpected BattlEye runtime state layout` | BattlEye 状态读取函数的指令校验失败，需要重新核对该引擎的状态布局 |
| `Unexpected message vtable layout` | 消息虚表布局与预期不符，不能直接沿用当前适配 |
| `Requires BattlEye disabled` | 插件读取到 BattlEye 实际未关闭；检查配置覆盖及启动方式，修改后完整重启 |
| `Could not attach compatibility hooks` | 检查 DHooks、SourceMod 的错误及引擎兼容性，确认必要函数可挂接 |
| 状态命令未知 | 插件未成功加载，或在客户端控制台执行时遗漏 `rcon`；先检查插件列表和错误日志 |
| `enabled=1`，但所有计数为 `0` | 尚未观察到对应库存请求；让拥有物品的 Windows 玩家重新连接并尝试使用物品，然后查看计数变化 |
| `routed` 增长，但物品仍不可用 | 路由发生不等于 Steam 校验通过；结合接收、回调、物品所有权及实际游戏表现排查 |
| `missing` 持续增长 | 目标通道中没有找到预期库存消息对象；保留版本及日志信息以供适配排查 |
| 运行期间出现 `enabled=0` | 当前 BattlEye 运行状态不符合路由条件；代码会跳过兼容路由，检查是否有配置在换图后重新启用它 |
| 文件覆盖后行为没有变化 | 内存中仍运行旧实例；卸载后重新加载，或重启服务器 |

遇到引擎校验失败时，应针对对应构建核对符号和布局。不要通过删除 `SetFailState` 或跳过指令、虚表检查来强行加载；这些检查约束了后续直接内存访问所依赖的实现。

## 从源码编译

直接使用仓库提供的 `.smx` 时无需编译。需要修改源码时，使用与目标 SourceMod 环境匹配的 SourcePawn 编译器，以及包含 `sourcemod.inc`、`dhooks.inc` 的 include 目录。

当前预编译文件使用 [SourcePawn Compiler 1.12.0.7257](https://github.com/alliedmodders/sourcemod/releases/tag/1.12.0.7257) 构建。本次重命名后的版本已通过编译，尚未重新进行游戏服务端实测。

以下示例在 Linux 上编译，将输出写入仓库的 `build/`，便于先检查再部署：

```bash
SERVER_ROOT="/srv/doi-server"
PLUGIN_SRC="/tmp/doi-linux-inventory-fix"
SM_SCRIPTING="$SERVER_ROOT/doi/addons/sourcemod/scripting"

mkdir -p "$PLUGIN_SRC/build"
"$SM_SCRIPTING/spcomp" \
    "$PLUGIN_SRC/addons/sourcemod/scripting/doi-linux-inventory-fix.sp" \
    -i"$SM_SCRIPTING/include" \
    -o"$PLUGIN_SRC/build/doi-linux-inventory-fix.smx"
```

确认编译成功后，将 `build/doi-linux-inventory-fix.smx` 与本项目对应 gamedata 按安装步骤部署。上述命令假设 SourceMod 安装中包含 Linux 编译器 `spcomp`；若没有，应从匹配的 SourceMod 包中获取编译工具。

常见编译问题：

- 找不到 `sourcemod` 或 `dhooks` include：检查 include 路径与开发文件是否完整。
- 找不到 `DynamicDetour` 等类型或接口：检查 `dhooks.inc` 是否支持本源码使用的 API。
- 编译器本身无法执行：检查编译器权限及其所需的 Linux 运行库。

编译成功仅代表源码通过编译，不代表目标引擎兼容。自行编译的 `.smx` 哈希也可能与下文预编译文件不同。

## 实现原理与版本适配

插件主要观察三个位置：

1. **消息查找：**在 `CNetChan::FindMessage` 返回后，检查查询编号是否为 `19`、BattlEye 是否关闭、原返回对象是否为预期的反作弊消息对象。
2. **路由替换：**从当前通道已经注册的消息对象中查找库存消息对象，找到后覆盖本次查找返回值。继续使用原有对象、解析器、处理函数和 Steam 所有权校验。
3. **过程计数：**观察 `CGameClient::ProcessSteamInventoryUpdate` 和 `CServerInventoryManager::OnSteamInventoryResult` 的调用，为验证和排错提供接收、回调计数。

加载前会校验关键函数的部分指令、消息类型实现、消息虚表入口和 BattlEye 状态读取函数。检查不通过时拒绝加载；这些检查不构成对所有后续内存访问和引擎行为的完整验证。

gamedata 使用 Linux 导出符号定位函数和全局对象。消息数组偏移、消息数量偏移、32 位指针步长、虚表偏移和指令检查等逻辑仍硬编码于源码中，因此 **gamedata 并非适配新引擎所需的全部信息**。

维护其他版本时，应同时审查 gamedata 和源码中的 ABI、偏移及指令假设，并在目标服务端实测。目前仓库没有自动构建或服务端集成测试脚本。

## 文件完整性校验

以下为仓库当前 `0.1.2` 三个发布文件的 SHA-256。修改源码、gamedata 或重新编译后，应重新生成对应值。

| 文件 | SHA-256 |
| --- | --- |
| `addons/sourcemod/plugins/doi-linux-inventory-fix.smx` | `445a85ffc838255409046f17e98563b14d24d6b1a673bb89809ea493e8ad18ec` |
| `addons/sourcemod/gamedata/doi-linux-inventory-fix.txt` | `9b9c598a500e4ed36e5b2693af65acfc7d1ae7e009734fe14245a9afc2bcea12` |
| `addons/sourcemod/scripting/doi-linux-inventory-fix.sp` | `bfc7c70f430fc5a9849560ba90e92ff44fe58d0e4951bbe7a880856e85e112fd` |

在仓库根目录执行：

```bash
sha256sum \
    addons/sourcemod/plugins/doi-linux-inventory-fix.smx \
    addons/sourcemod/gamedata/doi-linux-inventory-fix.txt \
    addons/sourcemod/scripting/doi-linux-inventory-fix.sp
```

在已部署服务器上验证时，先切换到游戏目录（例如 `/srv/doi-server/doi`）；若未上传源码，只校验前两个文件即可。

## 反馈问题

通过 GitHub Issues 反馈时，请提供以下信息，便于复现：

- 游戏服务端 `version` 输出，以及系统、进程架构信息。
- `meta version`、`sm version`、`sm exts list` 和 `sm plugins list` 的输出。
- 插件版本及是否自行修改、编译过源码或 gamedata。
- `sv_battleye` 查询值与 `doi-linux-inventory-fix_status` 输出。
- 对应时间段的插件日志、SourceMod 错误日志及操作步骤。
- 测试客户端平台、物品类型，以及是否由该测试账号实际拥有。

提交前移除 RCON 密码、服务器登录令牌及其他凭证。若报告不同构建的兼容问题，可附上服务端 Build ID 与引擎文件哈希。

## 许可

本项目采用 [Apache License 2.0](LICENSE) 开源协议。
