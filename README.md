# atv2nd-jailbreak

Source integration for the T8020 Apple TV jailbreak boot chain.

## Tested target

| Item | Version |
| --- | --- |
| Hardware | Apple TV 4K (2nd generation) |
| Product | AppleTV11,1 (`j305ap`) |
| SoC | T8020 (A12) |
| tvOS device-tested | 26.5 (`23L471`) |
| tvOS KPF static-tested | 26.3, 26.5 |
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

## Host requirements

Builds are currently supported on macOS with Xcode and the AppleTVOS SDK.
Install the host tools required by jbinit, yoloDFU, and the boot script:

```sh
brew install gnu-sed make ldid-procursus llvm pkg-config lz4 libirecovery
python3 -m pip install pyusb
```

## Prepare jbinit inputs

jbinit expects the Procursus binpack and both palera1n loader IPAs in its
`src` directory. These files are external inputs and are not submodules:

```sh
curl -fL https://static.palera.in/binpack.tar \
  -o components/jbinit/src/binpack.tar
curl -fL https://static.palera.in/artifacts/loader/universal_lite/palera1nLoader.ipa \
  -o components/jbinit/src/palera1nLoader.ipa
curl -fL https://static.palera.in/artifacts/loader/universal_lite/palera1nLoaderTV.ipa \
  -o components/jbinit/src/palera1nLoaderTV.ipa
```

The hashes used for the tested build are recorded under **jbinit** in
[RELEASE_STATUS.md](RELEASE_STATUS.md). The expected directory layout is:

```text
components/jbinit/src/
├── binpack.tar
├── palera1nLoader.ipa
└── palera1nLoaderTV.ipa
```

## Prepare the iBSS input

The yoloDFU patcher accepts the decrypted Apple TV 4K (2nd generation) iBSS
from tvOS 26.5, `mBoot-18000.120.36`. Its SHA-256 must be:

```text
c8d4aebc681d38a8925f3b86d0fa54cac23c39d525e53f088fd21c8045dc8f4d
```

Verify the input before building:

```sh
shasum -a 256 /path/to/decrypted-ibss.bin
```

Use this same tested iBSS when booting devices installed with tvOS 26.3 or
26.5. The patcher deliberately rejects a different iBSS hash.

## Build the boot artifacts

After preparing the three jbinit inputs and the decrypted iBSS, build the
complete bundle:

```sh
make verify
make artifacts IBSS_INPUT=/absolute/path/to/decrypted-ibss.bin
```

`make artifacts` builds jbinit, PongoOS, and yoloDFU, then writes the files
consumed by `boot.sh`:

```text
artifacts/
├── ibss.yolodfu.bin
├── pongo-container.bin
├── checkra1n-kpf-pongo
├── ramdisk.dmg
└── binpack.dmg
```

Build input and output hashes for the tested target are recorded in
[RELEASE_STATUS.md](RELEASE_STATUS.md).

## Build usbliter8

Build the RP2350 usbliter8 firmware with the Pico SDK:

```sh
make build-usbliter8 PICO_SDK_PATH=/path/to/pico-sdk
```

Flash `components/usbliter8/build/usbliter8.uf2` to the RP2350 and use the
procedure documented by the [usbliter8 repository](https://github.com/burnegg/usbliter8)
to place the Apple TV in pwned DFU. Reconnect the pwned device to the host.

## Boot from pwned DFU

Before running the boot chain, `irecovery -q` must report all three of these
values:

```text
CPID: 0x8020
PWND: usbliter8
MODE: DFU
```

Run the complete tethered boot sequence:

```sh
./boot.sh
```

The script sends the patched iBSS, waits for yoloDFU, sends PongoOS, loads KPF,
the jbinit ramdisk and binpack, and finally executes `bootx`. Optional kernel
arguments can be supplied with `BOOT_ARGS`:

```sh
BOOT_ARGS="-v" ./boot.sh
```

Artifact paths can be overridden with `IBSS`, `PONGO_CONTAINER`, `KPF`,
`RAMDISK`, and `BINPACK`.

The normal path does not demote the device and does not run `sep auto`; iBoot
retains Boot TZ0 ownership before the handoff to PongoOS.
