[中文](README.md) | [English](README.en.md)

# audio.cpp HIP (Windows) — AMD Radeon RX 5700 XT (gfx1010)

> ## ⚠️ 项目状态：已休眠（2026-10）
>
> 本项目（面向 AMD RX 5700 XT / gfx1010 的 Windows 自包含 HIP/ROCm 构建）
> **不再计划新版本**，转入存档维护。
>
> ### 为什么休眠
>
> 从上游 audio.cpp **v0.7（2026-08）** 开始使用本项目。当时在本机实测，
> **HIP 比 Vulkan 快**（仅限本机）。
>
> 在下一个计划更新的版本中，跑通了 **ROCm 10.1.0**，于是做了三后端对比
> （ROCm 6.4 / ROCm 10.1 / Vulkan）。测试条件：短文本 37 字、长文本约 118 字；
> 每个模型先冷启动（启动服务、加载模型）跑短文本，之后模型常驻，再依次跑短文本、长文本。
> **RTF（实时率）= 合成耗时 ÷ 音频时长，越小越快**；表内 `RTF-短` / `RTF-长` 均取热启动结果。
>
> 结果（时间单位秒，显存为进程峰值）：
>
> | 模型 | 后端 | 冷启动 | 热-短 | 热-长 | RTF-短 | RTF-长 | 显存 |
> |---|---|---|---|---|---|---|---|
> | Breeze-TTS-2 | ROCm 6.4 | 13.60 | 5.38 | 22.44 | 0.909 | 0.868 | 6308 MB |
> | Breeze-TTS-2 | ROCm 10.1 | 11.57 | 5.46 | 28.94 | 0.922 | 1.100 | 5086 MB |
> | Breeze-TTS-2 | Vulkan | 10.77 | 4.98 | 22.49 | 0.841 | 0.890 | 5501 MB |
> | Ming-3.0-TTS-0.5B | ROCm 6.4 | 7.21 | 3.47 | 11.86 | 0.542 | 0.547 | 1512 MB |
> | Ming-3.0-TTS-0.5B | ROCm 10.1 | 5.18 | 2.85 | 9.68 | 0.445 | 0.446 | 1529 MB |
> | Ming-3.0-TTS-0.5B | Vulkan | 4.72 | 3.11 | 11.22 | 0.510 | 0.529 | 1251 MB |
> | OmniVoice | ROCm 6.4 | 9.08 | 5.01 | 19.18 | 0.666 | 0.717 | 2308 MB |
> | OmniVoice | ROCm 10.1 | 7.48 | 4.88 | 18.83 | 0.649 | 0.716 | 2529 MB |
> | OmniVoice | Vulkan | 5.93 | 3.87 | 13.34 | 0.517 | 0.506 | 2089 MB |
> | Qwen3-TTS-VoiceDesign | ROCm 6.4 | 12.67 | 2.31 | 9.76 | 0.310 | 0.379 | 4683 MB |
> | Qwen3-TTS-VoiceDesign | ROCm 10.1 | 5.86 | 2.40 | 10.55 | 0.366 | 0.376 | 3851 MB |
> | Qwen3-TTS-VoiceDesign | Vulkan | 4.64 | 1.97 | 10.00 | 0.283 | 0.328 | 5365 MB |
>
> **小结**
> - Vulkan 在 4 个模型上**冷启动全部最快**；RTF 多数最低（Ming 在 ROCm 10.1 略低）。
> - ROCm 10.1 普遍快于 ROCm 6.4（冷/热启动），Breeze、Qwen3 显存更低；OmniVoice 显存略高。
> - 就当前结果看，**直接使用 Vulkan 版本是更好的选择**。
>
> ### 现在的状态
> - 已发布的 Release 压缩包仍可下载：**免装 ROCm SDK**，目标机只需普通 AMD Adrenalin 驱动。
> - 仓库代码、`package_hip_gfx1010.ps1` 打包脚本与文档保留原样，**不再更新**，可能随上游变动而失效。
> - Issue / PR 不保证响应。
>
> **最后验证**：上游 audio.cpp **`0.9.2+@082177ec`**、**Windows 11**、ROCm 6.4 / 10.1、MSVC 14.44、gfx1010。
>
> **说明**：上游 audio.cpp 迭代很快，以上仅为当前版本 + 本机（RX 5700 XT + Windows 11）的结果，非严谨测试，仅供参考。

面向 **64 位 Windows** 上 **AMD Radeon RX 5700 XT**（gfx1010 / RDNA1）的 **`audiocpp_server` 运行包**。
`audiocpp_server` 是 audio.cpp 的本地 HTTP 服务，提供 TTS、语音识别等音频模型推理。

运行包**已内置 ROCm 运行库与 rocBLAS 内核**，因此在装好普通 **AMD Adrenalin 驱动**的机器上即可直接运行。

## 运行验证

从本仓库 **Releases** 下载压缩包并解压，运行以下命令，输出应包含 `AMD Radeon RX 5700 XT`：

```cmd
audiocpp_server.exe --backend hip --list-devices
```

`audiocpp_server` 的完整用法见上游 [audio.cpp](https://github.com/0xShug0/audio.cpp)。

## 从源码构建

需要 ROCm 6.4（含 gfx1010 rocBLAS 内核）与 MSVC 14.44 工具集（VS 2022 Build Tools）。克隆本仓库时请带子模块（`--recurse-submodules`）。

```powershell
powershell -ExecutionPolicy Bypass -File .\package_hip_gfx1010.ps1
```

产物在 `dist\` 下。

## 许可

本项目采用 **GPL-3.0**（见 [`LICENSE`](LICENSE)）。

- 引擎：[audio.cpp](https://github.com/0xShug0/audio.cpp)（Apache-2.0）
- 随包携带的 gfx1010 ROCm 库文件（rocBLAS 等）来自
  [ROCmLibs-for-gfx1103-AMD780M-APU](https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU)（GPL-3.0）
- 其余 ROCm/HIP 二进制受 AMD EULA 约束

完整声明与许可全文见随包提供的 `THIRD_PARTY_NOTICES.txt` 和 `LICENSES\`。
