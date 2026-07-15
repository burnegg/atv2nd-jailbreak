# atv2nd-jailbreak

Source integration for the T8020 Apple TV jailbreak boot chain.

## Tested target

| Item | Version |
| --- | --- |
| Hardware | Apple TV 4K (2nd generation) |
| Product | AppleTV11,1 (`j305ap`) |
| SoC | T8020 (A12) |
| tvOS | 26.5 (`23L471`) |
| XNU | `xnu-12377.123.3~2/RELEASE_ARM64_T8020` |

## Components

| Component | Input | Output |
| --- | --- | --- |
| [usbliter8](https://github.com/burnegg/usbliter8) | SecureROM DFU | PWND DFU with the iBoot trampoline preserved |
| [yoloDFU](https://github.com/burnegg/yolodfu) | Patched iBoot trampoline | EL1 DFU runtime and Pongo loader container |
| [PongoOS](https://github.com/burnegg/PongoOS) | Pongo loader container | Patched XNU handoff |
| [jbinit](https://github.com/burnegg/jbinit) | Patched XNU | Rootless userspace bootstrap |

The component gitlinks and `components.lock.json` pin the source revisions used
by the tested chain.

## Clone

```sh
git clone --recurse-submodules https://github.com/burnegg/atv2nd-jailbreak.git
cd atv2nd-jailbreak
make verify
```

For an existing checkout:

```sh
git submodule update --init --recursive
make verify
```

## Build

Prepare jbinit's external inputs using the layout documented by the
[jbinit repository](https://github.com/burnegg/jbinit).

Build the host and device-side components in dependency order:

```sh
make build-jbinit
make build-pongo
make build-yolodfu
```

Build the RP2350 usbliter8 firmware with the Pico SDK:

```sh
make build-usbliter8 PICO_SDK_PATH=/path/to/pico-sdk
```

Create the patched iBSS, Pongo container, and jbinit binpack bundle:

```sh
make artifacts IBSS_INPUT=/path/to/decrypted-ibss.bin
```

Generated files are written to `artifacts/`. Build input and output hashes for
the tested target are recorded in [RELEASE_STATUS.md](RELEASE_STATUS.md).
