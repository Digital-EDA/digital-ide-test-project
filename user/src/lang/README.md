# Digital-IDE 当前语言服务支持说明

本文说明当前 `tools/server` 后端与 `tools/server/tests/0.5.x` VS Code 扩展已经接通的 HDL 语言服务能力。内容以当前源码和端到端测试为准，不把仅有配置项、语法着色或尚未接入 LSP 的代码算作已支持功能。

## 1. 适用语言和文件

| 语言 | 扩展名 | 语言服务后端 |
| --- | --- | --- |
| Verilog | `.v`、`.V`、`.vh`、`.vl` | SV 后端的 Verilog 方言路径 |
| SystemVerilog | `.sv`、`.svh` | SV 后端的 SystemVerilog 路径 |
| VHDL | `.vhd`、`.vhdl`、`.vho`、`.vht` | VHDL 后端 |

Verilog 与 SystemVerilog 进入同一个 SV 后端，但由文件后缀选择不同的解析入口：`.v`/`.vh`/`.vl` 始终使用 Verilog-2005 关键字约束和专属诊断，`.sv`/`.svh` 使用 `digital-ide.standard.systemverilog` 选择的 SystemVerilog 2017 或 2023 解析路径。当前测试工作区选择 2023；切换 SV 标准不会改变 `.v` 的方言。两者共享工程索引和 LSP provider，不共享语言方言判定。Verilog 方言的回归夹具还把 `logic`、`bit`、`priority`、`interface`、`package`、`class` 当作标识符；这些文本在 `.v` 中必须能解析，在 `.sv` 中则应按关键字处理。VS Code 语言贡献中还声明了大写 `.SV`，但当前服务端 URI 后缀分类没有接入 `.SV`，所以大写后缀目前只有编辑器语言识别，不能算完整语言服务支持。扩展也注册了 TCL/XDC/SDC、Yosys Script 等语言和语法高亮，但这些文件当前不进入 HDL LSP，因此不属于本文所述的语言服务范围。

SystemVerilog 标准可在工作区设置中选择，默认保持 2017 兼容行为：

```json
"digital-ide.standard.systemverilog": "2023",
"digital-ide.function.lsp.systemverilog.expandIncludes": true
```

服务端分别映射为 Slang 的 `1800-2017` 和 `1800-2023`。`expandIncludes` 默认为 `true`，同时控制编辑器增量解析、工作区初始化解析和语义诊断 compilation 的 include 展开；设为 `false` 后不再把 `.svh` 内容展开到包含它的编译单元，但 include 路径补全仍然可用。include 目录来自当前文件目录、工程 HDL 目录和 filelist 的 include 配置。修改该初始化设置后需要重启语言服务或重新加载 VS Code 窗口。

## 2. 总体能力矩阵

符号约定：`✓` 表示当前 LSP 已接入并由测试覆盖，`✗` 表示当前未接入或明确不提供。

| 功能 | Verilog/SystemVerilog | VHDL | 当前边界 |
| --- | --- | --- | --- |
| 打开、关闭、保存和增量编辑同步 | ✓ | ✓ | 使用增量文本同步，编辑后重新解析并刷新结果 |
| 工作区文件监视与多工作区文件夹 | ✓ | ✓ | 文件新增、修改、删除及工作区文件夹变化会触发重新协调 |
| 语法及语义诊断 | ✓ | ✓ | SV 还提供未激活预处理分支提示 |
| 标识符自动补全 | ✓ | ✓ | SV 的能力范围更完整，见下文 |
| 模块/实体例化补全 | ✓ | ✓ | SV 可生成完整例化 snippet；VHDL 使用语法上下文补全 |
| 跳转到定义 | ✓ | ✓ | 包括跨文件定义；SV 额外支持 include 和宏 |
| 查找引用 | ✓ | ✓ | 基于当前工作区语义快照 |
| 重命名前检查与重命名 | ✓ | ✓ | 只对当前能够唯一解析的符号生效 |
| 当前文件符号 | ✓ | ✓ | 用于 Outline、面包屑和符号导航 |
| 工作区符号搜索 | ✓ | ✓ | 支持按查询字符串搜索已索引符号 |
| 文档内同名引用高亮 | ✓ | ✓ | SV 按可见作用域限制匹配范围 |
| 悬停信息 | ✓ | ✓ | 显示声明、关联注释；数值可显示多进制解释 |
| 调用层次 | ✓ | ✓ | 主要表达模块/实体例化形成的上下游关系 |
| 整文档格式化 | ✓ | ✓ | 返回 TextEdit，由 VS Code 应用，不直接改写磁盘文件 |
| 选区格式化 | ✗ | ✗ | 服务端明确未声明此能力 |
| CodeLens | ✓ | ✗ | SV 模块提供运行和仿真入口；VHDL 返回空结果 |
| Inlay Hint | ✓ | ✗ | SV 提供 `endmodule`、有序参数和有序端口连接提示；VHDL 返回空结果 |
| Semantic Tokens | ✓ | ✗ | SV 支持 full、full/delta 和 range；TextMate grammar 继续提供基础语法着色 |
| 类型定义跳转 | ✓ | ✗ | SV 的 `textDocument/typeDefinition` 已接入变量、package、class、typedef alias 和跨文件类型解析 |
| Signature Help | ✗ | ✗ | 当前未声明函数/任务参数签名帮助 |
| Selection Range | ✗ | ✗ | 当前未声明智能选择范围 |
| Completion Resolve | ✗ | ✗ | 补全项一次返回，不再执行 resolve 请求 |

## 3. Verilog/SystemVerilog 补全

### 3.1 可见符号补全

普通标识符输入会自动请求补全。扩展已经为 Verilog 和 SystemVerilog 设置：

```json
"editor.quickSuggestions": {
  "other": "on",
  "comments": "off",
  "strings": "off"
}
```

SV 后端会根据光标所在的词法作用域返回当前可见定义，并优先选择最近作用域中的同名定义。当前作用域树可识别：

- module、interface、package、program、class；
- function、task；
- port、parameter、net、variable、genvar、typedef；
- instance、modport、generate block 和普通 block；
- covergroup、clocking block、checker、property、sequence。

例如已经声明 `reg [31:0] register;` 后，在同一可见作用域键入 `re`，补全列表会包含 `register`。

补全结果使用稳定的优先级：

| `sortText` | 补全来源 | 排序意图 |
| --- | --- | --- |
| `0` | 当前文件、当前可见作用域符号 | 最优先 |
| `1` | 已 import 的 package 成员 | 位于本地符号之后 |
| `2` | 完整模块例化 snippet | 位于可见符号和 import 成员之后 |
| `3` | 当前语法位置允许的关键字 | 最后显示 |

### 3.2 完整模块例化 snippet

输入一个当前工程可见的模块名时，可以得到带参数、实例名和全部端口连接的 snippet。例如：

```systemverilog
child #(
  .WIDTH(WIDTH)
) u_child (
  .clk(clk),
  .out(out)
);
```

参数值、实例名和端口信号都是可依次跳转的 snippet 占位符。候选来自已索引的 Verilog/SystemVerilog 模块，也会合并可见的 VHDL 实体信息。

### 3.3 package import 成员

当前支持以下两种导入后的非限定名补全：

```systemverilog
import common_pkg::*;
import common_pkg::IMPORTED_WIDTH;
```

通配导入会提供 package 中已收集到的成员；具名导入只提供指定成员。package 成员可包含参数、变量、typedef、函数和任务等作用域树能够识别的声明。

当前没有接通 `common_pkg::mem` 这种在 `::` 后按限定名列出成员的专用补全。也没有基于对象类型推导 `object.member` 的 class 成员补全。

### 3.4 参数区和端口区的 `.` 补全

在模块例化内部输入 `.` 时，后端会先判断光标位于哪个区域：

```systemverilog
child #(
  .WIDTH(8)       // 这里只补全参数
) u_child (
  .clk(clk),      // 这里只补全端口
  .out(out)
);
```

- `#(...)` 参数覆盖区只返回目标模块的 parameter；
- `(...)` 端口连接区只返回目标模块的 port；
- 可跨 Verilog/SystemVerilog 与 VHDL 查询目标模块或实体的参数/泛型和端口。

这里的 `.` 只表示例化参数或端口的命名关联，不等同于通用 class/object/层次成员访问补全。因此 `obj.member`、`u_child.internal_signal` 和多级层次路径当前还不能获得完整的类型驱动候选。对同一位置的有序参数/端口连接，Inlay Hint provider 还会显示对应的参数名、端口名和方向；命名连接只保留方向提示。

### 3.5 预处理、系统任务和 include 路径

LSP 声明的补全触发字符为 `.`、`$`、反引号、`"` 和 `/`。

- 输入 `$` 可补全 `$display`、`$monitor`、文件 I/O、仿真控制等系统任务/函数 snippet；
- 输入反引号可补全 `` `include``、`` `define``、`` `timescale`` 等指令以及工程内已解析的宏；
- 接受补全时，已经输入的 `$` 或反引号不会被 snippet 再重复插入；
- 在 `` `include "..."`` 或 `` `include <...>`` 中可补全文件和子目录；
- include 搜索会使用当前文件目录、工程中 HDL 文件所在目录以及 filelist 的 `+incdir+...` 配置；
- filelist 的 `+define+NAME` 和 `+define+NAME=VALUE` 会作为预定义宏送入解析器。

include 补全读取当前编辑缓冲区，因此文件尚未保存时也能按正在输入的路径前缀给出候选。

## 4. Verilog/SystemVerilog 导航和理解

### 4.1 跳转到定义

当前可以跳转到：

- 当前或外层词法作用域中的局部变量、net、port、parameter、typedef、function、task 等；
- 当前文件或其他工程文件中的 module/interface/package/class 等顶层定义；
- 模块例化的目标模块、实例名、命名参数和命名端口；
- `` `include`` 引用的文件；
- `` `define`` 定义的宏；
- 可匹配的跨语言模块/实体、参数/泛型和端口声明。

当同名定义无法唯一解析时，服务端不会随意选取一个局部定义。跨文件顶层定义会按当前文件优先并返回可用候选。

### 4.2 悬停

悬停会复用定义解析，显示声明文本及紧邻声明的注释。对 HDL 数值字面量还会显示宽度、signed/unsigned 解释以及二进制、八进制、十六进制或浮点转换结果。

### 4.3 符号、引用、重命名和层次

- Document Symbol 输出嵌套作用域，可用于 Outline 和面包屑；
- Document Highlight 高亮当前可见作用域内的同一符号；
- References、Prepare Rename、Rename 和 Workspace Symbol 已接入共享语义快照；
- Call Hierarchy 按模块例化关系提供 incoming 和 outgoing calls；
- 每个 SV 模块当前提供运行与仿真 CodeLens；
- 模块结束位置可显示 `endmodule` Inlay Hint；
- 有序参数赋值显示参数名，有序端口连接显示端口名和方向：输入 `←`、输出 `→`、双向 `↔`、引用 `&`；
- 命名端口连接保留方向提示，并提供跳转到端口声明的 label location；
- Inlay Hint 请求按 `range` 过滤，目标模块无法唯一解析时不产生误导性提示；有序连接提示附带转换为命名连接的 TextEdit。

Call Hierarchy 反映设计单元例化关系，不是 SystemVerilog function/task 的完整调用图，也不代表任意层次成员表达式已经支持跳转或补全。

### 4.4 格式化

SV 整文档格式化使用当前内置 formatter，并根据 VS Code 请求中的 `tabSize` 设置缩进宽度。格式化路径会携带预处理 trace 和 include 配置，保留预处理指令及未激活分支文本，并以重复格式化不再产生编辑作为稳定目标。当前不支持选区格式化。

扩展声明的 `digital-ide.function.lsp.formatter.vlog.default.style` 和 `digital-ide.function.lsp.formatter.vlog.default.args` 尚未传入当前 SV LSP 格式化请求；当前实际使用的是服务端内置的 Verible 兼容样式和编辑器 `tabSize`。

### 4.5 语义着色

Verilog/SystemVerilog 已在当前 Digital-IDE LSP 内接入 Semantic Tokens，没有启动 Vide 或其他第二套语言服务器。服务端复用当前编辑快照的 `Project`、Slang AST、`ScopeTree`、HDL 参数模型和预处理 trace，支持：

- `textDocument/semanticTokens/full`；
- `textDocument/semanticTokens/full/delta`，内容未变化时返回空 edits，变化时返回可替换旧 token 数据的 delta；
- `textDocument/semanticTokens/range`，token 坐标仍是相对整篇文档的 UTF-16 位置；
- module/interface/package/class、function/task、parameter、variable/net、generate/block 等作用域定义和引用；
- typedef 声明和引用、实例类型和实例名；
- 宏定义和宏使用；
- 模块例化中的命名参数与命名端口；
- 端口方向形成的 `read`、`write`、`ref` modifier；
- 标量 clock、reset 和普通端口的独立分类。

Semantic Tokens 是覆盖层，扩展已有的 `verilog.tmLanguage.json` 和 `systemverilog.tmLanguage.json` 仍负责关键字、数字、字符串、注释和操作符等基础语法着色。扩展默认启用 semantic token colors，并让读端口加粗、写端口加粗和下划线。

图例保留 Vide 的 `port_clock`、`port_reset`、`port_generic`、`instance`、`type_alias` 和 `generic` 自定义名称；实际 token 使用 Vide 相同的标准 fallback（例如 clock 使用 `keyword`、instance 使用 `variable`、typedef 使用 `type`），因此无需主题专门认识自定义名称也能显示颜色。

端口相关分类可分别配置：

```json
"digital-ide.function.lsp.semantic.tokens.port.clk.rst.enable": true,
"digital-ide.function.lsp.semantic.tokens.port.input.output.enable": true
```

第一项控制 clock/reset 与普通端口的区分，第二项控制按 input/output/inout/ref 添加读写 modifier。两项只影响 Verilog/SystemVerilog Semantic Tokens，不改变诊断、补全或 VHDL 行为。

Inlay Hint 可分别关闭有序端口和有序参数提示：

```json
"digital-ide.function.lsp.inlayHints.port.connection.enable": false,
"digital-ide.function.lsp.inlayHints.parameter.assignment.enable": false
```

这两个设置只影响提示显示，不会关闭端口/参数补全、定义跳转或格式化。

### 4.6 例化 Inlay Hint 的边界

例化提示只在目标设计单元能够唯一解析时生成。目标模块存在多个同名定义、目标端口不存在、连接是 `.*`，或请求 range 不覆盖连接时，服务端会跳过该连接，不猜测目标声明。non-ANSI header 会先按 header 中的顺序解析端口，再使用模块体内的 `input`/`output`/`inout`/`ref` 声明补齐方向和端口范围。

有序连接的 hint label 同时提供两个编辑器动作：跳转到目标端口声明，以及将当前有序连接转换为 `.port(signal)` 命名连接；空连接会生成 `.port()`。命名连接不再附加转换 TextEdit，只保留方向提示。

## 5. Verilog/SystemVerilog 诊断

SV 诊断由当前接入的 Slang 语法树和语义编译能力产生，然后统一转换为 VS Code 诊断，`source` 显示为 `Digital-IDE`。当前包括：

- 词法、预处理和语法诊断；
- 跨工作区编译单元的语义诊断；
- include 展开后的诊断，并把问题定位回实际 include 文件；
- 未激活预处理分支提示，标记为 `Unnecessary`；
- 基于诊断 code 的去重和稳定发布；
- 未保存编辑、保存、关闭、重新打开以及文件监视变化后的刷新。

被其他编译单元 include 的文件不会再被当作独立编译根重复编译，因此不会仅因为 include 而产生虚假的重复定义；真正独立的多个编译根如果声明同名设计单元，仍会报告重复定义。

`MissingTimeScale` 也是 Slang 语义诊断之一，不是 Digital-IDE 另外手写的规则。它表示同一设计中的 time scale 定义不一致或缺失。对不要求该规则的工程，可以按诊断 code 单独关闭，而不需要关闭其他语法或语义检查。

扩展目前会把 `digital-ide.function.lsp.linter.mode` 和 `digital-ide.function.lsp.linter.linter-level` 发送给服务端，但当前 SV Linter 构造路径没有读取这两个设置。当前已经确认有效的细粒度控制是下面的 `diagnostics.overrides`；不能把 `shutdown` 或 `linter-level` 视为已经接通的 SV 诊断开关。

## 6. 任意诊断的 Disable Quick Fix

VS Code 扩展为 Verilog、SystemVerilog 和 VHDL 注册了客户端 Quick Fix。满足以下条件的诊断会出现 `Disable this error`：

- `source` 是 `Digital-IDE`；
- 严重级别是 Error 或 Warning；
- 诊断带有字符串或数字 code。

执行后，扩展会把原有 overrides 与新 code 合并，并写入当前工作区文件夹的 `.vscode/settings.json`：

```json
"digital-ide.function.lsp.diagnostics.overrides": {
  "MissingTimeScale": "off",
  "AnyOtherDiagnosticCode": "off"
}
```

过滤按诊断 code 进行，作用于当前工作区中所有 `source: Digital-IDE` 且 code 相同的诊断。修改后现有诊断会立即刷新；关闭并重新打开文件或再次打开工作区后，配置仍然生效。

这不是服务端声明的通用 `textDocument/codeAction`。Quick Fix 由扩展客户端提供，目前只生成“按 code 关闭”这一类动作，不包含自动改写 HDL 代码的修复。

## 7. VHDL 语言服务

### 7.1 工程和库

VHDL 后端使用独立的 VHDL parser/semantic project。初始化时会读取工程 VHDL 文件、所选标准及标准库。当前测试工作区使用相对于工作区根目录的库路径：

```json
"digital-ide.standard.vhdl": "2008",
"digital-ide.lib.vhdl.path": "../../../vhdl/vhdl_libraries"
```

相对路径以打开的工作区根目录解析。库目录必须能够提供 VHDL 标准 package，否则 VHDL 工程不会进入完整语义分析状态。

### 7.2 补全与导航

VHDL 当前支持：

- 根据光标前的 VHDL 语法上下文给出关键字、声明和例化候选；
- entity、architecture、package、signal、constant、generic、port 等解析器可识别对象的补全；
- 例化位置合并当前工程中的 VHDL 实体与可见 SV 模块；
- 跳转到设计单元、声明、例化目标、generic/parameter 和 port；
- Document Highlight、Document Symbol、Hover；
- References、Prepare Rename、Rename、Workspace Symbol；
- entity 例化形成的 Call Hierarchy incoming/outgoing 关系。

VHDL 悬停会显示声明和相关注释，也支持对可识别数值显示多进制解释。

### 7.3 诊断与格式化

VHDL 工程分析会发布 parser/semantic diagnostics，并在增量编辑修复问题后清除过期诊断。诊断同样使用 `Digital-IDE` 作为 source，因此带 code 的 Error/Warning 也可以使用通用 Disable Quick Fix。

整文档格式化已接入。服务端先按 VHDL-2008 解析当前缓冲区，再返回覆盖整篇文档的 TextEdit；若文本已经稳定，则返回空编辑。当前没有选区格式化。扩展声明的 VHDL keyword case、type name case、align comments 和 indentation 设置尚未传入这条格式化请求路径。VHDL CodeLens 和 Inlay Hint 接口当前返回空结果。

## 8. 工程索引和实时更新

语言服务的结果不仅来自当前打开文件，也来自工作区工程模型：

- 从 `.vscode/property.json` 的硬件源码、仿真源码和显式文件集发现 HDL；
- 读取 filelist 中的源文件、嵌套 `-f`、`+incdir+` 和 `+define+` 元数据；
- 读取自定义库和 VHDL 库配置；
- 遵守 `.dideignore`；
- 监视 HDL 文件及工程配置变化；
- 支持工作区文件夹增加和移除；
- 对未保存编辑使用内存中的当前文本，而不是重新读取旧磁盘内容；
- 在增量版本或文本 hash 不一致时请求全量文本重新同步，避免用旧位置发布新结果。

大型工作区可能采用延迟索引，打开或请求目标文件时再提升解析优先级。因此刚启动扩展时，完整工作区符号和跨文件结果可能比当前文件结果稍晚出现。

## 9. 当前明确未完成的成员能力

为避免把“解析器能识别语法”误认为“编辑器已经提供完整语义体验”，当前边界如下：

| 场景 | 状态和边界 |
| --- | --- |
| `import pkg::*` / `import pkg::name` 后使用非限定成员 | ✓ 补全已接入 |
| `pkg::member` 在 `::` 后列出 package 成员 | ✗ 未接入专用补全 |
| class 声明及其成员出现在作用域/文档符号中 | ✓ 已支持基础收集 |
| 根据 class 变量类型完成 `object.member` | ✗ 未实现完整类型推导和成员补全 |
| 模块例化的 `.PARAM` / `.port` | ✓ 已支持并区分参数区、端口区 |
| `instance.internal_signal` 层次成员补全 | ✗ 未实现 |
| 多级层次名的完整跳转、引用和重命名 | ✗ 未实现完整语义解析 |
| function/task 参数 Signature Help | ✗ 未实现 |

因此，目前可以把 package import、词法作用域符号和模块例化命名关联作为稳定可用功能；class/object 成员和任意设计层次成员仍应视为后续能力，不能仅凭 Outline 中能看到 class 或 instance 就认为已经完整支持。

## 10. 语言服务测试集

这里的测试不是与用户工程脱离的样例集合，而是直接使用本目录原有的 `svlog/`、`vlog/`、`vhdl/` 结构构成一个混合 HDL 小工程。最终顶层是 `vhdl/lang_vhdl_top.vhd`，数据通路为：

```text
input_a/input_b
   -> SV lang_sv_core (package/include + lang_sv_leaf)
   -> Verilog lang_vlog_bridge (non-ANSI header)
   -> VHDL lang_vhdl_stage
   -> result
```

SV 核心先计算 `input_a + input_b + LANG_BIAS`，Verilog 和 VHDL 各进行一次按位取反，因此最终 `result` 保持该加法结果。核心还实例化 `lang_sv_advanced` 作为同一工作区中的语法探针，探针不驱动公开结果，但使用真实的 SV module/parameter/port 连接和 generate 数据路径。这让模块、package、include、非 ANSI Verilog 端口、VHDL entity/architecture/generic/port map 和跨语言实例都处在同一条实际工程路径上。

`tests/` 目录只保存协议运行器和清单；它通过 stdio 启动 `digital-server`，发送 `initialize`、打开上述工程文件，再按语言调用 provider。`.dideignore` 只排除原目录中与本测试顶层无关的旧示例；本测试集不保留已删除的 `lang_invalid.sv`。

文件布局：

```text
tests/
  manifest.json            原目录 HDL 文件清单和查询锚点
  run.py                   stdio LSP 测试运行器
svlog/
  lang_sv_include.svh      include、宏和系统任务
  lang_sv_pkg.sv           package、typedef alias、class、function
  lang_sv_leaf.sv          SV 子模块和参数/端口
  lang_sv_core.sv          SV 业务核心、局部变量、task、hover 和例化锚点
  lang_sv_advanced.sv      完整 SV 语法模块，合并 interface 和 feature probe
vlog/
  lang_vlog_bridge.v       non-ANSI Verilog 模块和 Verilog-2001 语法锚点
vhdl/
  lang_vhdl_pkg.vhd        VHDL package、subtype 和 function
  lang_vhdl_stage.vhd      VHDL entity/architecture
  lang_vhdl_top.vhd        混合语言最终顶层
```

SV 测试覆盖：普通局部/package 符号补全、系统任务和 include 补全；跨文件模块定义；变量类型定义（含 package、typedef alias 和跨文件解析）；引用、悬停、文档高亮、文档/工作区符号、prepare rename/rename、整文档格式化；Semantic Tokens 的 full、range 和 full/delta；CodeLens、模块结束/有序参数/有序端口 Inlay Hint、Call Hierarchy；以及合并后的 interface、generate、SVA、class、checker 和 covergroup 语法矩阵。Verilog 测试覆盖 non-ANSI 模块定义、wire/reg/integer/tri/wand/wor、函数/task、`always @*`、`casez`/`casex`、循环 generate 和文档符号、补全、悬停、格式化；同时用 `logic`、`bit`、`priority`、`interface`、`package`、`class` 作为 Verilog 合法标识符，验证 `.v` 不误用 SystemVerilog 关键字表。VHDL 测试覆盖 entity/component 补全、跨文件定义、悬停、引用、高亮、文档符号、重命名、格式化，并明确断言当前 `typeDefinition`、Semantic Tokens、CodeLens、Inlay Hint 为空结果。

### 10.1 按功能覆盖 Slang all.sv 语法族

这里不是把 `tools/slang/tests/regression/all.sv` 原样复制进工程，而是把其中的语法族重新组织到现有混合语言功能里。`lang_sv_core` 实例化 `lang_sv_advanced`，因此语法覆盖模块和 `input_a/input_b -> result` 加法数据路径属于同一个工作区工程，而不是孤立 parser fixture。

`tests/manifest.json` 的 `syntax_coverage` 是可执行覆盖矩阵。每一项把来自 `all.sv` 的语法族映射到真实源文件和源码标记，运行器启动后逐项检查：

- 编译单元时间单位、属性、package、import/export、参数类型和 typedef；
- ANSI/non-ANSI module、automatic module、interface、嵌套 interface、modport、clocking；
- extern/interface/macromodule/primitive/UDP table；
- net、wor、trireg、strength、路径延迟、alias、连续/过程赋值、force/release；
- fork/wait/wait_order、case/inside/matches/casez/randcase、数组和 foreach；
- always_ff/always_comb/always_latch、break/continue、generate for/if/case 和命名 generate scope；
- enum/struct/union/tagged union、property/sequence/assert/assume/cover、checker、bind；
- specify/specparam/timing checks、program/config；
- class、extern method、泛型 class、extends/implements/interface class、constraint、randsequence；
- covergroup/coverpoint/cross/bins、动态数组、queue、streaming/type/$bits、nettype/let；
- DPI import/export 以及系统任务和时序控制。

测试还检查 `lang_sv_advanced`、generate 分支、checker、covergroup、specify module 等符号，Semantic Tokens、Inlay Hint，以及从 `lang_sv_core` 跳转到该模块的定义。Inlay Hint 的方向、non-ANSI header 顺序、range 过滤、空连接、设置开关和歧义目标专项测试位于 SV server 的单元测试中；混合工程运行器负责验证真实工作区协议接入。`all.sv` 只是语法覆盖的参考清单，不会被复制或作为字节级测试输入；功能源可以保持自己的模块名、数据流和跨语言接口。

从 `tools/server` 目录执行：

```bash
cargo build --bin digital-server
PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3.10 -B \
  tests/project/xilinx/temp/user/src/lang/tests/run.py
```

成功时输出实际清单文件数（当前为 9 个）和所有语言服务 provider 检查结果；运行器会先请求 `process/request` 和 `hdlparams/request` 等待后台工程索引完成，再对跨文件 provider 做短暂重试。`run.py --server PATH --manifest PATH` 可用于替换服务端二进制或清单。VHDL 文件还可以用 `ghdl -a --std=08` 做分析；混合顶层中的 SV/Verilog component 在纯 VHDL 工具中会显示未绑定 warning，这是预期的跨语言绑定边界。该测试集属于语言服务协议/开发回归，不替代厂商综合、仿真或板卡测试。
