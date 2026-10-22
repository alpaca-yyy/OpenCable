# OpenCable

免费、MIT 开源的 macOS Type-C 与充电状态工具。SwiftUI 原生界面，无第三方依赖、无账号、无网络请求、无付费功能。它是独立实现的同类工具，不是 WhatCable 的破解版本或原始源码。

## 使用

本机编译版：`dist/OpenCable.app`，打开即可使用；菜单栏点击连接器图标可查看当前功率或打开面板。主窗口关闭后菜单栏仍可使用，从菜单选择退出可彻底停止采样。

- 中文面板与菜单栏功率显示。
- 每 5 秒读取 Type-C 控制器：连接状态、当前协议、端口支持协议、系统报告的有源/光纤/显示信号标记。
- 充电器报告功率、系统报告电压/电流、电池电量、输入功率曲线（最近 10 分钟，仅内存）。
- USB 设备名称与 VID/PID、原始速率代码。
- 本次运行期间的端口、USB 和电源变化记录；暂停采样、隐藏空端口。
- 导出或复制 JSON 报告；不包含硬件序列号、平台 UUID。设备名和 VID/PID 仍可能具有识别性，分享前自行检查。

## 编译与验证

macOS 14+、Apple Command Line Tools（`xcode-select --install`，若未安装）。无须 Homebrew、Node、Python、联网下载 Swift 依赖或管理员权限。

```sh
./scripts/build.sh
./scripts/test.sh
./dist/opencable-cli --json
open dist/OpenCable.app
```

本机发布二进制为 Apple Silicon arm64。Intel Mac 可在本机使用同一源码构建，尚未实机验证。完整 Xcode 环境另可运行 `swift test`；仅 Command Line Tools 缺少 XCTest 时，使用无第三方依赖的 `scripts/test.sh`。

本机构建使用临时签名，尚未做 Apple Developer ID 签名或公证。公开给其他 Mac 分发之前应完成签名、公证和更多机型测试；不建议让用户关闭系统安全保护。

## 读数边界

端口支持 USB3/DisplayPort 并不证明线材支持它。当前充电功率也不代表线材额定功率。系统报告的供电档位不等于实测吞吐量或实验室认证。原始字段缺失时展示“未知”，而不是零或否。

- `AppleTCController` 和 `AppleSmartBattery` 是 Apple 系统提供但未承诺稳定的数据源；部分 Mac 不公开这些字段。
- 输入功率读取 `PowerTelemetryData.SystemPowerIn`，按 mW 换算，属未公开单位解释；本机以输入电压×电流交叉核验。它不是插座侧功率，也不是电池侧净充电功率。
- 档位读取 `AdapterDetails.UsbHvcMenu.MaxVoltage/MaxCurrent`，按 mV/mA 换算。当前系统报告电流可表示协商/上限参数，不是实时负载电流。
- 端口号码是系统控制器编号，尚未映射为机身左/右位置。
- USB 设备仅为全局枚举，尚未关联到特定 Type-C 端口；速率代码保持原值，不伪装为测速结果。
- 5 秒轮询可能漏过短暂的插拔事件；设备不提供某字段时对应功能不可用。

首版暂未实现：完整 E-marker/VDO 解码、SMC 分端口功率、线阻估算、Thunderbolt 拓扑、外接显示器详情、系统通知、登录启动、小组件、云端数据库。未验证真实插拔、USB 数据外设、外接显示器及不同芯片机型，不声称与原版完全等价。

## 来源和许可

所有分发源码、文案与界面独立编写。未包含原版可执行文件、图标、本地化资源、反编译代码或分析数据库。可自由使用、修改和再分发，详见 [LICENSE](LICENSE)。分析过程和本机证据在本项目之外单独保存，避免将原版资源混入发行包。

离屏 UI 与真实后台采样验证：`./dist/OpenCable.app/Contents/MacOS/OpenCable --self-check /tmp/OpenCable-preview.png`，等待约 11 秒生成带实时读数的界面图；该命令不操作其他应用。
