# T8020 jailbreak chain

This repository pins the independently publishable components of the T8020
boot chain. It contains no firmware, device identifiers, runtime logs, or
hardware-debug workflows.

## Component boundaries

| Component | Producer | Consumer | Owned transition |
| --- | --- | --- | --- |
| usbliter8 | SecureROM DFU | patched iBoot | PWND DFU and trampoline preservation |
| yoloDFU | patched iBoot trampoline | Pongo loader | owned EL1 runtime and ROM DFU transport |
| PongoOS | loader container | XNU | platform setup, KPF, and kernel handoff |
| jbinit | patched XNU | rootless userspace | bootstrap and spawn integration |

`components.lock.json` binds every component to a source repository, a clone
base or independent root, a clean release branch, and an exact release commit.
Those commits must be published before a fresh checkout can reproduce the
chain.

## Checkout layout

Place exact checkouts under `components/` using the directory names recorded in
the lock file, then verify them:

```sh
make verify
```

The verifier requires each checkout HEAD to equal the pinned release commit,
proves that the upstream base is an ancestor, and rejects tracked changes.

## Build order

The normal build order is jbinit, PongoOS, and yoloDFU. usbliter8 is an
independent firmware build. Required firmware and third-party userspace inputs
must be supplied separately and are intentionally not part of this repository.

```sh
make build-usbliter8 PICO_SDK_PATH=/path/to/pico-sdk
make artifacts IBSS_INPUT=/path/to/decrypted-ibss.bin
```

The artifact target produces the patched iBSS, loader-plus-Pongo container,
and jbinit binpack under `artifacts/`. It does not transfer or execute them.
