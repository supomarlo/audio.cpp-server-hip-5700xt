[中文](README.md) | [English](README.en.md)

# audio.cpp HIP (Windows) — AMD Radeon RX 5700 XT (gfx1010)

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
