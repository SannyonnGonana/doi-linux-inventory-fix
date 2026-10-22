# doi-linux-inventory-fix

[![简体中文](https://img.shields.io/badge/Language-简体中文-lightgrey)](README.md)
[![English](https://img.shields.io/badge/Language-English-blue)](README.en.md)

Fixes the **inventory validation message ID mismatch between the Day of Infamy (DOI) Windows client and Linux dedicated server**, allowing client inventory messages to reach the server's native Steam inventory validation pipeline.

Plugin name: `doi-linux-inventory-fix`  
Version: `0.1.2`  
Author: `SannyonnGonana`

This SourceMod plugin targets DOI Linux dedicated servers deployed through SteamCMD and running a **32-bit server process**. At runtime, it routes message ID `19` from Windows clients to the server's existing inventory message object for ID `20`, preserving the game's own parser, handlers, and Steam ownership checks.

> **Before installing:** Make sure the game server already runs correctly, SourceMod and DHooks load successfully, and BattlEye is actually disabled. The plugin depends on a specific engine implementation and is not guaranteed to work with every DOI server build.

## Contents

- [Scope and requirements](#scope-and-requirements)
- [Repository files](#repository-files)
- [Before installation](#before-installation)
- [Installation](#installation)
- [Verifying the fix](#verifying-the-fix)
- [Commands and logs](#commands-and-logs)
- [Updating, rolling back, and uninstalling](#updating-rolling-back-and-uninstalling)
- [Troubleshooting](#troubleshooting)
- [Building from source](#building-from-source)
- [Implementation and engine compatibility](#implementation-and-engine-compatibility)
- [File integrity](#file-integrity)
- [Reporting issues](#reporting-issues)
- [License](#license)

## Scope and requirements

In the protocol mismatch addressed by this project, the Windows client sends inventory updates as message ID `19`, while the Linux server's native inventory message uses ID `20`. The server's original object for ID `19` is `CLC_AntiCheatPacket`. The plugin corrects which message object receives the incoming data.

The original deployment notes report successful player testing of brass knuckles and faction cosmetics. Those results apply to that deployment; they do not establish compatibility with other server builds, client platforms, or every inventory item.

| Component | Requirement or scope |
| --- | --- |
| Game | Day of Infamy, with the game directory named `doi` |
| Server | Linux 32-bit engine matching the symbols, instructions, and memory layout checked by the plugin |
| Operating system | A 64-bit Linux host is acceptable if it can run the game's 32-bit server and its dependencies |
| Plugin framework | Metamod:Source and SourceMod versions that work with the target DOI server |
| Extension | DHooks with `DynamicDetour` support |
| BattlEye | Must actually be disabled; the plugin does not disable it for you |
| Client | The fix targets Windows clients using message ID `19` for inventory updates |

The plugin preserves Steam inventory and item ownership checks. It does not grant inventory items or unlock content the player does not own. Steam service outages, ownership problems, and unrelated causes of unavailable cosmetics are outside its scope.

The repository does not record the exact game Build ID, Metamod:Source version, or SourceMod version used in the original deployment, so a complete, verified compatibility matrix is not available. Windows servers, 64-bit server processes, and other games are outside the current support scope.

## Repository files

```text
.
├── LICENSE
├── README.md
├── README.en.md
└── addons/
    └── sourcemod/
        ├── plugins/
        │   └── doi-linux-inventory-fix.smx    # Compiled plugin; required at runtime
        ├── gamedata/
        │   └── doi-linux-inventory-fix.txt    # Engine symbol configuration; required at runtime
        └── scripting/
            └── doi-linux-inventory-fix.sp     # SourcePawn source code
```

For a precompiled installation, only the `.smx` and gamedata `.txt` files are required. The `.sp` file is provided for review, modification, and compilation. **Uploading only the `.smx` is not enough to run the plugin.**

## Before installation

### 1. Locate the server directory

The examples below use these paths:

- `/srv/doi-server`: The game server installation root, containing `srcds_run` and the `doi/` directory.
- `/tmp/doi-linux-inventory-fix`: The downloaded or extracted repository, containing the README files and `addons/` directory.

Replace these example paths with your actual locations. Install the plugin under **`server-root/doi/addons/sourcemod/`**, rather than `server-root/addons/`.

An example server layout:

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

### 2. Check SourceMod and DHooks

If the framework is not installed, obtain Linux builds suitable for your DOI server and install them first:

- [Metamod:Source official website](https://www.sourcemm.net/)
- [SourceMod official downloads](https://www.sourcemod.net/downloads.php)

Run these commands in the **server console**:

```text
meta version
sm version
sm exts list
```

Confirm that Metamod:Source and SourceMod report their versions, and that DHooks appears in the extension list without loading errors. The [DHooks documentation](https://wiki.alliedmods.net/DHooks_%28SourceMod_Scripting%29) states that DHooks is included with SourceMod 1.12 and newer builds of 1.11. Check the extension's actual status on your server; this project has not been tested against every such version.

If `sm` is an unknown command, fix the SourceMod installation first. If DHooks fails to load, resolve the extension error before troubleshooting this plugin's inventory counters.

### 3. Make sure BattlEye is disabled

Check the server configuration that actually takes effect, such as `doi/cfg/server.cfg`, and disable BattlEye:

```cfg
sv_battleye 0
```

This is a game server setting, not a plugin setting. Check whether startup parameters, map configurations, or the playlist override it, then fully restart the server. You can query the setting from the server console:

```text
sv_battleye
```

**The configuration value is only a diagnostic clue.** The plugin reads the engine's BattlEye runtime state. If loading fails with `Requires BattlEye disabled`, the runtime requirement is still not met. Deleting the BattlEye directory or editing a configuration file that is not applied does not establish that BattlEye is disabled.

## Installation

### Step 1: Download the files

On the GitHub repository page, choose **Code → Download ZIP**, extract the archive, and locate the directory containing `addons/`. You can also clone the repository with Git.

If the project provides a Release, you can use a complete package containing the `.smx` and its matching gamedata. Keep files from the same release together.

### Step 2: Back up an existing installation

Skip this step for a first installation. When updating, stop the server before backing up, or unload the plugin first using the [management commands](#commands-and-logs) if you need to update while the server is running.

The following are **Linux shell commands**. Run them as an account with permission to read and write the server directory:

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

### Step 3: Upload the plugin and gamedata

Use SFTP, your server panel's file manager, or a shell to copy the files to these locations:

| Repository file | Destination on the server |
| --- | --- |
| `addons/sourcemod/plugins/doi-linux-inventory-fix.smx` | `/srv/doi-server/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx` |
| `addons/sourcemod/gamedata/doi-linux-inventory-fix.txt` | `/srv/doi-server/doi/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt` |

If the repository is already extracted on the server, run:

```bash
SERVER_ROOT="/srv/doi-server"
PLUGIN_SRC="/tmp/doi-linux-inventory-fix"

install -m 0644 "$PLUGIN_SRC/addons/sourcemod/plugins/doi-linux-inventory-fix.smx" \
    "$SERVER_ROOT/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx"
install -m 0644 "$PLUGIN_SRC/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt" \
    "$SERVER_ROOT/doi/addons/sourcemod/gamedata/doi-linux-inventory-fix.txt"
```

These commands assume SourceMod is already installed and the destination directories exist. The game server account must be able to read the files and write to SourceMod's `logs/` directory. The `.smx` and `.txt` files do not need executable permissions.

Avoid these directory mistakes:

- Do not create `doi/addons/addons/sourcemod/` on the server.
- Do not put the entire repository directory inside `plugins/`.
- Do not put the gamedata file in `configs/` or rename it.
- Merge the repository's `addons/` into the existing installation, preserving existing files. Do not replace the server's entire `addons/` directory with this repository's copy.

### Step 4: Load the plugin

If the server is stopped, start it. SourceMod will automatically load the plugin from `plugins/`.

If the server is already running, execute these commands in the **server console**:

```text
sm plugins load doi-linux-inventory-fix.smx
sm plugins list
doi-linux-inventory-fix_status
```

To manage the server through the game client's console, configure RCON first and add the `rcon` prefix:

```text
rcon sm plugins load doi-linux-inventory-fix.smx
rcon sm plugins list
rcon doi-linux-inventory-fix_status
```

The `sm ...` and status commands are not Linux shell commands. The plugin's status command is registered as a server command and is not a regular chat command.

If SourceMod reports that the plugin is already loaded, query its status directly; there is no need to load it again.

### Step 5: Check the loading status

The plugin name should appear in `sm plugins list` without a failed status. Example status output:

```text
[DLIF] enabled=1 routed=0 received=0 callbacks=0 missing=0
```

Zero counters are normal before any relevant inventory messages arrive. Continue with the player test below.

The plugin has no separate `.cfg` file to fill out and no plugin ConVar required to enable it. It starts working after a successful load, stays loaded across map changes, and loads automatically after a server restart. You do not need to add repeated `sm plugins load` commands to `server.cfg`.

## Verifying the fix

Use a **Windows client whose account actually owns the inventory items being tested**:

1. After the plugin loads successfully, run `doi-linux-inventory-fix_status` and record the initial counters.
2. Have the player reconnect to the server and try selecting and using owned inventory content, such as brass knuckles or faction cosmetics.
3. Query the status again and check whether `routed`, `received`, and `callbacks` have increased.
4. Confirm that the item or cosmetic actually works in game, and check for SourceMod errors.
5. After a map change or server restart, check the loading status and repeat the test.

Possible output is shown below. The numbers are illustrative:

```text
[DLIF] enabled=1 routed=2 received=2 callbacks=2 missing=0
```

The fields mean:

| Field | Meaning | Interpretation |
| --- | --- | --- |
| `enabled` | `1` when the engine BattlEye state address is valid and its enabled flag is off | This is neither a manually configurable switch nor proof of successful inventory validation |
| `routed` | Number of message ID `19` lookups successfully redirected to the registered inventory message object | An increase confirms that compatibility routing was triggered |
| `received` | Number of calls to the native `ProcessSteamInventoryUpdate` function | An increase confirms entry into the native inventory receive path |
| `callbacks` | Number of calls to the native inventory result callback | An increase confirms a result callback was observed; the result may still be invalid |
| `missing` | Number of times the target routing branch could not find a registered inventory message object | Repeated increases require investigation of engine compatibility and message registration |

**These counters are not player counts or successful unlock counts.** Native receive and callback counters can include other inventory processing. The three counters do not need to match, and asynchronous callbacks may arrive later. Judge the result using item ownership, actual in-game behavior, and server error logs together.

Counters accumulate while the plugin is loaded and do not reset on map changes. Unloading and loading the plugin again, or restarting the server, resets them.

## Commands and logs

### Management commands

Run these in the server console. Add `rcon` when using them through RCON.

| Command | Purpose |
| --- | --- |
| `sm plugins list` | List plugins and their loading status |
| `sm exts list` | Check extensions, including DHooks |
| `sm plugins load doi-linux-inventory-fix.smx` | Load the plugin |
| `doi-linux-inventory-fix_status` | Print the runtime condition and cumulative counters |
| `sm plugins unload doi-linux-inventory-fix.smx` | Unload the plugin and remove its hooks |

### Log location

Plugin log:

```text
doi/addons/sourcemod/logs/doi-linux-inventory-fix.log
```

Follow it from a Linux shell:

```bash
tail -f /srv/doi-server/doi/addons/sourcemod/logs/doi-linux-inventory-fix.log
```

Example log entry:

```text
[DLIF] route_windows19_to_inventory20 routed=1 received=0 callbacks=0 missing=0
```

| Stage marker | Meaning |
| --- | --- |
| `loaded` | Initialization and hook attachment succeeded |
| `map_start` | Current counters recorded at map start |
| `route_windows19_to_inventory20` | Compatibility routing occurred |
| `native_inventory_receive` | The native inventory receive function was entered |
| `native_result_processed` | The native inventory result callback finished |
| `inventory_message_missing` | The registered inventory message object was not found |
| `unloaded` | Current counters recorded when the plugin ended |

To limit log volume, each plugin load records only the first 8 routing events, first 8 receive events, first 16 result callbacks, and first 3 missing-object events. Counters continue increasing after those limits; use the status command to read them.

The plugin log contains only stage markers and counters. It does not record player accounts, credentials, or inventory contents. Check `doi/addons/sourcemod/logs/errors_*.log` and the server console for SourceMod loading errors. An `unloaded` entry alone does not prove that the plugin previously loaded successfully.

## Updating, rolling back, and uninstalling

### Updating

1. Stop the server or unload the plugin first.
2. Back up the existing `.smx` and gamedata `.txt` files.
3. Replace both files with a matching pair from the new release.
4. Start the server or load the plugin.
5. Query its status and perform a player inventory test.

Overwriting the `.smx` on disk does not replace the plugin instance already loaded in memory. Reload it or restart the server.

If the game server is also updated, engine symbols, instructions, or layouts may change. Check the loading result after updating. Recompiling unchanged source does not resolve engine compatibility differences.

### Rolling back

Stop the server or unload the plugin, restore both the backed-up `.smx` and gamedata `.txt` to their original locations, then start the server or load the plugin. The old plugin still requires an engine matching its checks; rolling back the plugin may not restore compatibility after a game update.

### Disabling or uninstalling

Run this in the server console:

```text
sm plugins unload doi-linux-inventory-fix.smx
```

This stops only the currently loaded instance. To prevent automatic loading on the next startup, move the `.smx` out of the automatic loading location. For example, run these commands in a **Linux shell**:

```bash
SERVER_ROOT="/srv/doi-server"
mkdir -p "$SERVER_ROOT/doi/addons/sourcemod/plugins/disabled"
mv "$SERVER_ROOT/doi/addons/sourcemod/plugins/doi-linux-inventory-fix.smx" \
    "$SERVER_ROOT/doi/addons/sourcemod/plugins/disabled/doi-linux-inventory-fix.smx"
```

For complete removal, unload the plugin and remove its `.smx`, gamedata `.txt`, and optional `.sp` source file. You can retain the logs for troubleshooting. To enable it again, move the `.smx` back into `plugins/` and load it, making sure the matching gamedata is still present.

## Troubleshooting

| Symptom or error | Possible cause and action |
| --- | --- |
| `sm` / `meta` is an unknown command | The framework did not load, or the command was entered in a Linux shell. Check Metamod:Source and SourceMod in the server console first |
| Required `dhooks` extension is not running, or a DHooks native is missing | Check `sm exts list` for extension errors. Make sure the extension matches SourceMod, the engine, and the server process architecture |
| `DOI Linux 32-bit only` | Check whether the plugin was installed for another game. This particular error is triggered by the game directory name check; it is not a complete OS or process architecture check |
| `Missing verified gamedata` | Check that `gamedata/doi-linux-inventory-fix.txt` exists, has the correct name, and is readable. Check SourceMod for gamedata parsing errors |
| `Unrecognized engine symbols` | One or more required symbols could not be resolved. Verify the gamedata and game version. If the files match and are intact, engine adaptation is required |
| `Engine build differs from the audited 19/20 protocol` | Function instructions or message type implementations differ from the checked build. Review the target engine and update the implementation |
| `Unexpected BattlEye runtime state layout` | The instruction check for the BattlEye state accessor failed. Review the state layout for that engine |
| `Unexpected message vtable layout` | The message virtual table layout differs from the expected implementation. The current adaptation cannot be used as-is |
| `Requires BattlEye disabled` | BattlEye is not actually disabled according to the engine state. Check configuration overrides and startup settings, then fully restart the server |
| `Could not attach compatibility hooks` | Check DHooks and SourceMod errors, engine compatibility, and whether the required functions can be hooked |
| The status command is unknown | The plugin did not load successfully, or the `rcon` prefix was omitted in the client console. Check the plugin list and error logs |
| `enabled=1`, but all counters remain `0` | No relevant inventory request has been observed. Have a Windows player who owns the items reconnect and try using them, then check the counters again |
| `routed` increases, but the item is unavailable | Routing does not prove successful Steam validation. Check receive and callback counters, item ownership, and in-game behavior together |
| `missing` keeps increasing | The expected inventory message object was not found in the target channel. Retain version information and logs for compatibility investigation |
| `enabled=0` appears during operation | The current BattlEye state does not meet the routing condition, so compatibility routing is skipped. Check whether a configuration re-enabled it after a map change |
| Replacing files has no effect | The old plugin instance may still be running in memory. Unload and load it again, or restart the server |

When an engine check fails, review the symbols and layout for that build. Do not force the plugin to load by removing `SetFailState` calls or skipping instruction and virtual table checks. Those checks constrain the implementation assumptions used by subsequent direct memory accesses.

## Building from source

You do not need to compile anything to use the supplied `.smx`. To modify the source, use a SourcePawn compiler matching the target SourceMod environment and an include directory containing `sourcemod.inc` and `dhooks.inc`.

The current precompiled file was built with [SourcePawn Compiler 1.12.0.7257](https://github.com/alliedmodders/sourcemod/releases/tag/1.12.0.7257). The renamed version compiles successfully but has not yet been retested on a game server.

This Linux example writes the output to the repository's `build/` directory so you can check it before deployment:

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

After a successful build, deploy `build/doi-linux-inventory-fix.smx` with this project's matching gamedata using the installation steps above. The command assumes the SourceMod installation includes the Linux `spcomp` compiler. If it does not, obtain the build tools from a matching SourceMod package.

Common build problems:

- Missing `sourcemod` or `dhooks` include: Check the include path and development files.
- Missing types or APIs such as `DynamicDetour`: Check that `dhooks.inc` supports the API used by this source.
- The compiler itself cannot run: Check executable permissions and its required Linux runtime libraries.

A successful compilation does not establish compatibility with the target engine. A locally compiled `.smx` may also have a different hash from the precompiled file listed below.

## Implementation and engine compatibility

The plugin observes three main points:

1. **Message lookup:** After `CNetChan::FindMessage` returns, it checks that the requested ID is `19`, BattlEye is disabled, and the original returned object is the expected anti-cheat message object.
2. **Routing override:** It searches the current channel's registered message objects for the inventory object. If found, it overrides the lookup result, retaining the original object, parser, handler, and Steam ownership checks.
3. **Processing counters:** It observes calls to `CGameClient::ProcessSteamInventoryUpdate` and `CServerInventoryManager::OnSteamInventoryResult` to provide receive and callback counters for verification and troubleshooting.

Before attaching hooks, the plugin checks selected function instructions, message type implementations, message virtual table entries, and the BattlEye state accessor. It refuses to load if these checks fail. The checks do not fully verify every subsequent memory access or engine behavior.

The gamedata locates functions and global objects using Linux exported symbols. Message array and count offsets, the 32-bit pointer stride, virtual table offsets, and instruction checks remain hardcoded in the source. **Updating gamedata alone may therefore be insufficient to support a different engine build.**

To support another build, review both the gamedata and the source's ABI, offset, and instruction assumptions, then test on the target server. The repository currently has no automated build or server integration test scripts.

## File integrity

These SHA-256 hashes identify the three current `0.1.2` release files in this repository. Regenerate the corresponding hashes after changing the source or gamedata, or rebuilding the plugin.

| File | SHA-256 |
| --- | --- |
| `addons/sourcemod/plugins/doi-linux-inventory-fix.smx` | `445a85ffc838255409046f17e98563b14d24d6b1a673bb89809ea493e8ad18ec` |
| `addons/sourcemod/gamedata/doi-linux-inventory-fix.txt` | `9b9c598a500e4ed36e5b2693af65acfc7d1ae7e009734fe14245a9afc2bcea12` |
| `addons/sourcemod/scripting/doi-linux-inventory-fix.sp` | `bfc7c70f430fc5a9849560ba90e92ff44fe58d0e4951bbe7a880856e85e112fd` |

Run this from the repository root:

```bash
sha256sum \
    addons/sourcemod/plugins/doi-linux-inventory-fix.smx \
    addons/sourcemod/gamedata/doi-linux-inventory-fix.txt \
    addons/sourcemod/scripting/doi-linux-inventory-fix.sp
```

To check deployed files, first change to the game directory, such as `/srv/doi-server/doi`. If you did not upload the source, check only the first two files.

## Reporting issues

When opening a GitHub issue, include:

- The game server's `version` output, operating system, and process architecture.
- Output from `meta version`, `sm version`, `sm exts list`, and `sm plugins list`.
- The plugin version and whether you modified or compiled the source or gamedata yourself.
- The `sv_battleye` value and `doi-linux-inventory-fix_status` output.
- Relevant plugin and SourceMod error logs, with timestamps and reproduction steps.
- The test client's platform, item type, and whether that account actually owns the item.

Remove RCON passwords, server login tokens, and other credentials before posting. For compatibility reports involving a different build, include the server Build ID and engine file hashes if available.

## License

This project is licensed under the [Apache License 2.0](LICENSE).
