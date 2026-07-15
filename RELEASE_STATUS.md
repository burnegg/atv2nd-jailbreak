# Release verification

The hashes below bind the deterministic outputs of the component revisions in
`components.lock.json`. Host binaries containing absolute paths and disk images
containing filesystem metadata are verified by a successful clean build rather
than by byte identity.

## usbliter8

Built with `T8020_TRAMPOLINE_PRESERVE=1` for
`waveshare_rp2350_usb_a`.

| Output | Size | SHA-256 |
| --- | ---: | --- |
| `usbliter8.uf2` | 111616 | `dbfe0777f5792bb9343ad0de4c8a70ddef631318fcd847b2d0fad406bc9331ce` |

`usbliter8.elf` embeds absolute source and Pico SDK paths. The flashable UF2 is
the release hash boundary.

## yoloDFU

The patched iBSS was built from input SHA-256
`c8d4aebc681d38a8925f3b86d0fa54cac23c39d525e53f088fd21c8045dc8f4d`.
The Pongo container was built from the Pongo image recorded below.

| Output | Size | SHA-256 |
| --- | ---: | --- |
| `hook.bin` | 16 | `23a1087c51b1e595a34ceaaaa88a328596df0df5b33c334eb575b96b19e29b1e` |
| `wrapper.bin` | 184 | `05af224b98e5b24e2c3c3d644fe423db5c54ca7e7d3fc9840e6d0947a5f12da4` |
| `vector.bin` | 2048 | `17892619afe63a8934e37ebe0e925e6456a514a9b12a9eb35c69f1d29925b4a0` |
| `runtime.bin` | 3928 | `b96edbfedcc866a4c2169fd8c1f510ae838d270a9a089f4b2f318748a451fd0f` |
| `loader.bin` | 512 | `b52c3205068f9eb4d4b60f9093b06bdbfb52490c88d36b84f72020f5bf77d7d3` |
| `ibss.yolodfu.bin` | 2125216 | `16c536c1bbdedf54f83c42a97ffae22338049d2878d54a2fadb8863929efcbbc` |
| `pongo-container.bin` | 142267 | `aa23187b328c306c2bcc8b812b8ed6e27e984ca1195f130dd39ce4edbbffa1ca` |

The clean runtime blobs and patched iBSS are byte-identical to the accepted
pre-publication artifacts.

## PongoOS and KPF

Built with `PONGO_SRAM_BASE=0x19c000000`. The static KPF test used the complete
fileset kernel payload with SHA-256
`c04e5909c99d50cfc47aeb0e6159e1c866c32893accbaf30d70418cdd0b62d5c`
and completed successfully.

| Output | Size | SHA-256 |
| --- | ---: | --- |
| `Pongo.bin` | 254768 | `31d4915f5f5f382b08eae81ad135455a46ba33399c240de92d7804a43678d421` |
| `checkra1n-kpf-pongo` | 128280 | `d712c13362da9956c5a82e204b6f171679246551587fe894ead1ed22fe57a224` |
| `kpf-test.macos` | 167168 | `62730a29646f7987687308316b59cf45c3ef25c3d2cb1b13cdc951df261d2ea1` |
| patched kernel dump | 56295424 | `4487c307a4af45257cf88eb9ce83ab4fea41bff3067ebcaf81eddf640752fe7d` |

## jbinit

The build used three untracked external inputs. They must be supplied by the
publisher and are identified here only by content hash.

| Input | Size | SHA-256 |
| --- | ---: | --- |
| `binpack.tar` | 6369280 | `964b65f68eee41099670d7035f4f41d520e7acc656a5702af87dd6e9e8d11ab0` |
| `palera1nLoader.ipa` | 252204 | `d68a7c9aae8ed016b572ab0fb50cf150ac185a13d255ceb40a730cf4150ee6e2` |
| `palera1nLoaderTV.ipa` | 261208 | `a0c7dcdef5ca6c9ab48defd7568cba7bff713269c03aa96ab4c048a3512ae3ee` |

A clean recursive checkout successfully produced `ramdisk.dmg` and
`binpack.dmg` with the original jbinit input layout. Their HFS and compressed
image metadata is not used as a reproducibility boundary.

## Publication blockers

- PongoOS and jbinit retain their upstream license files.
- The usbliter8 clone base contains no license file. Its release fork must not
  be presented as generally redistributable until distribution terms are
  resolved.
- yoloDFU is an independent repository. Its standalone loader reproduces an
  openra1n reference payload, so that provenance and attribution boundary must
  be resolved before public release.
- This integration repository also needs an explicit license choice before
  public release.
- Firmware, kernelcache, userspace archives, and generated images remain
  external inputs and must not be committed.
