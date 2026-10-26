[中文](README.md) | [English](README.en.md)

# audio.cpp HIP (Windows) — AMD Radeon RX 5700 XT (gfx1010)

> ## ⚠️ Project status: dormant (Oct 2026)
>
> This project (a self-contained Windows HIP/ROCm build of audio.cpp for the
> AMD RX 5700 XT / gfx1010) **is no longer receiving new releases** and is kept
> for archival purposes only.
>
> ### Why it is dormant
>
> We started using audio.cpp at **v0.7 (Aug 2026)**. At that time, testing on this
> machine showed **HIP was faster than Vulkan** (this machine only).
>
> In the next planned version we got **ROCm 10.1.0** working, so we ran a
> three-backend comparison (ROCm 6.4 / ROCm 10.1 / Vulkan). Test setup: short text
> of 37 characters and long text of about 118 characters; for each model we first
> ran the short text on a cold start (start service + load model), then, with the
> model resident, ran the short and long text in turn.
> **RTF (real-time factor) = synthesis time ÷ audio duration; lower is faster.**
> The `RTF-short` / `RTF-long` columns use the warm runs.
>
> Results (time in seconds, memory is per-process peak):
>
> | Model | Backend | Cold | Warm-short | Warm-long | RTF-short | RTF-long | VRAM |
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
> **Summary**
> - Vulkan had the **fastest cold start for all 4 models**; it also had the lowest
>   RTF in most cases (Ming was slightly lower on ROCm 10.1).
> - ROCm 10.1 was generally faster than ROCm 6.4 (cold/warm); Breeze and Qwen3
>   used less VRAM, OmniVoice slightly more.
> - Based on these results, **using the Vulkan build directly is the better choice**.
>
> ### Current state
> - Existing Release archives remain available: **no ROCm SDK required** — only a
>   normal AMD Adrenalin driver on the target machine.
> - The code, `package_hip_gfx1010.ps1` packaging script and docs are kept as-is
>   but **no longer updated**; they may break as upstream changes.
> - Issues / PRs may go unanswered.
>
> **Last verified**: upstream audio.cpp **`0.9.2+@082177ec`**, **Windows 11**,
> ROCm 6.4 / 10.1, MSVC 14.44, gfx1010.
>
> **Note**: upstream audio.cpp moves quickly, so results differ between versions;
> the above is only from the current version on this machine (RX 5700 XT +
> Windows 11) and is not a rigorous test — for reference only.

A self-contained `audiocpp_server` **package for the AMD Radeon RX 5700 XT** (gfx1010 / RDNA1) on
64-bit Windows. `audiocpp_server` is audio.cpp's local HTTP service for audio-model inference
(TTS, speech recognition, ...).

The package **bundles the ROCm runtime libraries and rocBLAS kernels**, so it runs directly on a
machine with a normal **AMD Adrenalin driver**.

## Run & verify

Download the archive from this repo's **Releases** and extract it, then run the following — the
output should contain `AMD Radeon RX 5700 XT`:

```cmd
audiocpp_server.exe --backend hip --list-devices
```

For the full CLI usage, see upstream [audio.cpp](https://github.com/0xShug0/audio.cpp).

## Build from source

Requires ROCm 6.4 (with gfx1010 rocBLAS kernels) and the MSVC 14.44 toolset (VS 2022 Build Tools).
Clone with submodules (`--recurse-submodules`).

```powershell
powershell -ExecutionPolicy Bypass -File .\package_hip_gfx1010.ps1
```

Output goes to `dist\`.

## License

This project is licensed under **GPL-3.0** (see [`LICENSE`](LICENSE)).

- Engine: [audio.cpp](https://github.com/0xShug0/audio.cpp) (Apache-2.0)
- The bundled gfx1010 ROCm library files (rocBLAS, ...) come from
  [ROCmLibs-for-gfx1103-AMD780M-APU](https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU) (GPL-3.0)
- Other ROCm/HIP binaries are governed by the AMD EULA

Full notices and license texts ship in `THIRD_PARTY_NOTICES.txt` and `LICENSES\`.
