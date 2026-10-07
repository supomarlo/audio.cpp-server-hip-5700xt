[中文](README.md) | [English](README.en.md)

# audio.cpp HIP (Windows) — AMD Radeon RX 5700 XT (gfx1010)

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
