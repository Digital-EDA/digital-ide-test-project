# Digital IDE Test Project

用于验证 [Digital IDE](https://github.com/Digital-EDA/Digital-IDE) 的综合测试工程，覆盖 HDL 语言服务、混合语言仿真、波形查看、Xilinx 工程管理和板级调试。工程包含源代码、测试脚本以及 Vivado/Vitis 生成的 IP、BSP 和硬件产物快照。

不同测试的入口和依赖各不相同：语言服务通过 LSP 脚本验证，FFT 通过仿真器执行，波形可直接在扩展中打开，硬件调试则需要对应开发板和厂商工具。仓库没有一个可以执行所有场景的统一测试命令。

## 测试内容

| 场景 | 入口 | 验证内容 | 依赖与边界 |
| --- | --- | --- | --- |
| HDL 语言服务 | `user/src/lang/` | Verilog、SystemVerilog、VHDL 的补全、导航、符号、重命名和格式化等 LSP 请求 | 需要匹配版本的 `digital-server`；脚本的源码目录定位需要适配 |
| FFT/IFFT 仿真 | `user/sim/fft/fft_ifft_tb.sv` | 四个实例的连续帧、同步、有效数据和 AXI Stream 帧边界 | 完整测试需要 XSim 或支持混合语言的 ModelSim/Questa，以及公共 HDL 库 |
| 波形查看与会话恢复 | `wave.vcd`、`wave.fst`、`wave.dws` | 波形加载、信号树、数值格式、缩放、游标、标记和信号比较 | 可用于手动回归；DWS 保存了原机器上的波形绝对路径 |
| Xilinx 工程与 Zynq PS | `user/bd/system/system.bd` | Block Design/IP 导入、顶层识别、约束及硬件导出流程 | 当前器件为 `xc7z010clg400-1`，配置顶层为 `system_wrapper` |
| 裸机软件与 GDB | `user/sdk/template/template/src/helloworld.c` | Cortex-A9 应用编译、ELF 下载、断点和串口输出 | 需要 Vitis、匹配的硬件平台/BSP、调试连接及开发板 |
| ILA/VIO 硬件调试 | `user/src/func/func.sv` | 条件采集、立即采集、级联触发、VIO 读写回环和 LED 控制 | 独立测试顶层 `func`；需切换顶层及对应约束并重新构建 |
| XPM FIFO 样例 | `user/sim/xpm_tb.v` | 64 位写入、8 位读出的 FIFO 仿真探索 | 尚未形成可直接通过的回归，存在端口和信号连接问题 |

## 目录结构

```text
.vscode/
  property.json          Digital IDE 工程、器件、顶层和公共库配置
  settings.json          HDL 标准、仿真器、厂商工具及诊断设置
  launch.json            Cortex-A9 GDB 调试配置
user/
  src/lang/              混合 HDL 语言服务测试文件及 Python 回归脚本
  src/ifft/              64 点流水线 IFFT RTL
  src/func/              ILA/VIO 板级调试 RTL
  sim/fft/               FFT/IFFT 混合语言 testbench
  sim/xpm_tb.v           XPM FIFO 仿真样例
  ip/xfft_v9/            Xilinx FFT IP 配置、HDL 包装和仿真模型
  bd/system/             Zynq Block Design 及生成文件
  data/map.xdc           板级管脚与电气约束
  data/debug/            ILA/VIO 调试配置
  data/FFT/in/           保留的 FFT 输入向量
  sdk/                   硬件交接数据、Vitis 工作区、BSP、FSBL 和应用
template.bit             已保存的 FPGA 配置文件
template.ltx             已保存的硬件调试探针文件
wave.vcd / wave.fst       波形样例
wave.dws                 波形会话快照
```

## 开始使用

```bash
git clone https://github.com/Digital-EDA/digital-ide-test-project.git
cd digital-ide-test-project
code .
```

安装 Digital IDE 后，将仓库根目录作为 VS Code 工作区打开。按要执行的测试准备依赖，并调整以下配置：

1. 在 [工作区设置](.vscode/settings.json) 中设置本机 Vivado、Vitis、ModelSim 路径。现有配置来自 Vivado/Vitis 2022.2 和 ModelSim 20.4 环境，不代表其他版本已验证。语言标准设为 SystemVerilog 2023、VHDL 2008，并启用 include 展开。
2. 查看 [工程配置](.vscode/property.json)：工程名为 `template`，器件为 `xc7z010clg400-1`，综合顶层为 `system_wrapper`，仿真顶层为 `fft_ifft_tb`，仿真时长为 `all`。
3. 通过 Digital IDE 配置并解析 `library.hardware.common` 列出的公共 HDL 库。`Basic/Math/Advance/FFT/Flow` 及其数学、存储器依赖不随本仓库提供；只克隆本仓库不足以运行完整 FFT 测试。
4. 软件调试前更新 [launch.json](.vscode/launch.json) 的 ELF、GDB 路径和调试服务器地址，并安装提供 `cppdbg` 的 VS Code C/C++ 扩展。现有 ELF 路径和 SDK 构建文件包含原机器的绝对路径，需要重新配置或由 Vitis 重新生成。

工作区当前关闭了 `MissingTimeScale`、`misplaced_attribute_spec` 和 `unresolved` 三类诊断。检查诊断能力时应留意这些覆盖项；它们不适用于下面直接启动服务端的 Python 测试会话。

## HDL 语言服务回归

[manifest.json](user/src/lang/tests/manifest.json) 列出 9 个测试文件和 21 组 SystemVerilog 语法覆盖项。测试工程包含 package、include、跨文件模块与 VHDL 实体例化，以及由 VHDL 顶层连接的 SV/Verilog 数据通路。

[run.py](user/src/lang/tests/run.py) 启动真实 `digital-server`，通过标准输入/输出发送 LSP 请求：

- SystemVerilog：局部/package 补全、系统任务和 include 补全，定义与类型定义跳转、引用、悬停、符号、重命名、格式化，以及 semantic tokens、CodeLens、Inlay Hint、调用层次响应。
- Verilog：符号、补全、悬停、格式化，并检查 `.v` 中保留 Verilog 方言用法，例如允许将 `logic`、`interface` 等文本作为标识符。
- VHDL：补全、实体定义、引用、悬停、符号、重命名、格式化和调用层次；还检查当前未支持的类型定义跳转、semantic tokens、CodeLens、Inlay Hint 返回空结果。
- 语法矩阵：检查 interface、class、约束、covergroup、SVA、checker/bind、DPI、generate 等语法标记，以及部分符号、着色和跨文件导航结果。

部分检查只断言响应类型或非空结果；语法标记覆盖也不等于完整 HDL 标准符合性验证。详细说明见 [语言服务文档](user/src/lang/README.md)，实际检查范围以脚本为准。

### 运行条件与命令

需要 Python 3.10+、可执行的 `digital-server` 和相应的 VHDL 标准库。脚本使用 `select` 读取子进程管道，适合 Linux/WSL 等 POSIX 环境，不应假定原生 Windows 可以直接运行。

**独立克隆后的路径需要先适配。** 当前脚本用 `Path(__file__).resolve().parents[8]` 推算 `SERVER_ROOT`，并据此查找 `target/debug/digital-server` 和 `tests/vhdl/vhdl_libraries`。该固定层级不适用于任意克隆位置，在较浅路径甚至会在解析命令行前报错。运行前应将脚本中的 `SERVER_ROOT` 改为实际的服务端源码根目录，并确认 VHDL 库位置；`--server` 仅覆盖可执行文件路径，不会修正标准库路径。

完成上述路径适配后，从本仓库根目录运行（替换示例路径）：

```bash
python3 user/src/lang/tests/run.py \
  --server /path/to/digital-server
```

成功时输出：

```text
PASS: 9 real mixed-HDL files and all language-service provider checks
```

测试脚本请求格式化及重命名编辑，但不将返回的编辑写回测试源文件。本仓库不包含服务端源码，不能在这里直接执行 `cargo build` 构建服务端。

## FFT/IFFT 混合语言仿真

默认仿真顶层 `fft_ifft_tb` 并行驱动四个 64 点变换实例：本地 `ifftmain`、公共库 FFT、公共库 IFFT，以及 Xilinx `xfft_v9`。每个实例输入 3 轮、每轮 4 帧，共 12 帧、768 个样本；激励为脉冲及频点 1、4、11 的余弦，轮间改变幅度和相位。

检查项包括帧同步、每帧 64 个样本、无 X/Z、测试帧不全零、Xilinx AXI Stream 的 `TLAST` 位置及输入帧事件，并设置全局超时防止握手停滞。成功日志以以下文本开头：

```text
FFT/IFFT regression passed: 64 points, 3 rounds, 12 frames per DUT
```

准备好公共库和 Xilinx IP 仿真库后，在 Digital IDE 中刷新工程并运行项目仿真：

- Vivado XSim：使用当前 `fft_ifft_tb` 顶层及 `simRuntime: all`。
- ModelSim/Questa：需要混合语言支持，保留厂商库编译和 IP 仿真源导出步骤。当前快速仿真器配置为 `modelsim`。
- Verilator 无法直接运行包含 VHDL XFFT 模型的完整测试；只测纯 Verilog/SV 部分需要另行调整 testbench 和源文件集合。

这是数据流与帧完整性回归，未与软件 DFT 比较，不验证各实现的精度、缩放或输出顺序；FFT 与 IFFT 也没有串接成往返回路。当前激励由 testbench 内部生成，不读取 `user/data/FFT/in/` 中的向量。更多细节见 [FFT 测试说明](user/sim/fft/README.md)。

## 波形查看

直接用 Digital IDE 打开 `wave.vcd` 或 `wave.fst`，可检查信号加载、时间轴、缩放、游标和数值显示。VCD 样例来自 `Registers_tb`，可观察读写寄存器地址、数据、时钟和复位；它不是上述 FFT 测试的输出。

`wave.dws` 保存了信号列表、显示格式、颜色、高度、视口、游标、标记和信号比较状态，可用于会话恢复测试。该快照引用原机器的 `wave.vcd` 绝对路径；换机器后如果找不到波形，应先打开本地 VCD 并重新保存会话。这里的波形和会话是人工查看夹具，没有自动判定 UI 正确性的脚本。

## 硬件与软件调试

### Zynq 工程及裸机应用

`user/bd/system/` 保存了包含 Zynq PS 的 Block Design、DDR/FIXED_IO 与以太网相关接口；当前管脚约束对应 `system_wrapper`。`user/sdk/` 包含硬件交接数据、Cortex-A9 standalone BSP、FSBL 和 Hello World 应用，可用于验证硬件导出到软件构建、ELF 下载及 GDB 调试流程。

使用前在 Vitis 中重新建立或导入适合当前路径的工作区，确认硬件平台与开发板一致，再构建应用并配置调试服务器。应用正常运行会输出 `Hello World` 和 `Successfully ran Hello World application`。当前 GDB 配置连接 `127.0.0.1:3000`，连接后执行 `load` 下载 ELF，再继续执行。

### ILA/VIO 调试

[func.sv](user/src/func/func.sv) 提供递增计数器和流水灯，使用 HDL 属性声明两组 ILA 和一组 VIO。[func.debug.toml](user/data/debug/func.debug.toml) 配置：

- ILA 0：深度 1024，采样条件 `sample_valid == 1`，触发条件 `condition_counter == 129`。
- ILA 1：深度 1024，用于立即采集，并配置 ILA 0 到 ILA 1 的级联触发。
- VIO 0：`control` 输出与 `loopback` 输入形成读写回环；`control[3]` 启用 LED 覆盖，低两位选择 LED 值。

执行该场景需要将综合顶层切换为 `func`，加载上述调试配置，并在 [map.xdc](user/data/map.xdc) 中使用对应开发板的 `func` 管脚和时钟约束。当前启用的是 `system_wrapper` 约束，`func` 对应段落被注释，不能直接沿用。重新综合、实现和生成匹配的 BIT/LTX 后，再连接硬件验证触发和 VIO 回读。

根目录的 `template.bit`、`template.ltx` 是历史构建快照，文件名不保证它们对应当前顶层、源代码或目标板；板级测试应使用同一次构建生成的匹配产物。

## 尚未完善的样例与产物说明

- `user/sim/xpm_tb.v` 的模块名是 `tb_xpm`，并非当前默认仿真顶层。它仍引用未声明的 `rstn`、`data_in_valid`，使用的时钟端口及部分状态输出连接需要核对。应先修复连接并补充自动检查，再将其作为 FIFO 回归使用。
- `.gitignore` 忽略 `prj/`、`.Xil/` 和 `.dide/`。已跟踪的 IP、SDK 工作区和构建产物仍保留在仓库中，用于复现开发现场。
- 部分子目录说明保留了旧开发树路径；在独立仓库中请优先使用本 README 给出的入口，并核对实际配置。
- IFFT RTL 带有原作者的 LGPL 声明，Xilinx 生成代码和 BSP 带有各自的许可声明；使用相关文件时应保留并遵循对应声明。
