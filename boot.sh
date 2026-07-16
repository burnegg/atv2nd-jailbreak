#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON="${PYTHON:-python3}"
TIMEOUT="${TIMEOUT:-30}"
BOOT_ARGS="${BOOT_ARGS:-}"

IBSS="${IBSS:-$ROOT/artifacts/ibss.yolodfu.bin}"
PONGO_CONTAINER="${PONGO_CONTAINER:-$ROOT/artifacts/pongo-container.bin}"
KPF="${KPF:-$ROOT/artifacts/checkra1n-kpf-pongo}"
RAMDISK="${RAMDISK:-$ROOT/artifacts/ramdisk.dmg}"
BINPACK="${BINPACK:-$ROOT/artifacts/binpack.dmg}"

USBLITER8CTL="$ROOT/components/usbliter8/usbliter8ctl"
SEND_PONGO="$ROOT/components/yolodfu/tools/send_pongo.py"
PONGOTERM="$ROOT/components/PongoOS/scripts/pongoterm"

die() { echo "error: $*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
need_file() { [[ -f "$1" ]] || die "missing artifact: $1 (run make artifacts)"; }

usb_has() {
    ioreg -p IOUSB -l 2>/dev/null |
        awk -v marker="$1" 'index($0, marker) { found = 1 } END { exit !found }'
}

wait_usb() {
    local marker="$1" label="$2" deadline=$((SECONDS + TIMEOUT))
    while (( SECONDS < deadline )); do
        usb_has "$marker" && return 0
        sleep 1
    done
    die "timed out waiting for $label"
}

need_cmd ioreg
need_cmd irecovery
need_cmd make
need_cmd "$PYTHON"
for file in "$IBSS" "$PONGO_CONTAINER" "$KPF" "$RAMDISK" "$BINPACK" \
            "$USBLITER8CTL" "$SEND_PONGO"; do
    need_file "$file"
done

query="$(irecovery -q 2>/dev/null || true)"
grep -Fq 'CPID: 0x8020' <<<"$query" || die "T8020 DFU device not found"
grep -Fq 'MODE: DFU' <<<"$query" || die "device is not in DFU mode"
grep -Fq 'PWND: usbliter8' <<<"$query" || \
    die "DFU is not pwned; run usbliter8 with the RP2350 and reconnect to this host"
unset query

if [[ ! -x "$PONGOTERM" ]]; then
    make -C "$ROOT/components/PongoOS/scripts" pongoterm
fi

echo '[1/4] Booting patched iBSS'
"$PYTHON" "$USBLITER8CTL" boot "$IBSS"
wait_usb 'YOLO:checkra1n' yoloDFU

echo '[2/4] Sending Pongo container'
"$PYTHON" "$SEND_PONGO" "$PONGO_CONTAINER"
wait_usb '"USB Product Name" = "PongoOS USB Device"' PongoOS

echo '[3/4] Loading KPF and jbinit artifacts'
{
    printf 'fuse lock\n'
    printf '/send %q\nmodload\npalera1n_flags 0x2\n' "$KPF"
    printf '/send %q\nramdisk\n' "$RAMDISK"
    printf '/send %q\noverlay\n' "$BINPACK"
    if [[ -n "$BOOT_ARGS" ]]; then
        printf 'xargs %s\n' "$BOOT_ARGS"
    else
        printf 'xargs\n'
    fi
    printf 'bootx\n'
} | "$PONGOTERM" &
term_pid=$!
trap 'kill "$term_pid" 2>/dev/null || true' EXIT

deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
    if ! kill -0 "$term_pid" 2>/dev/null; then
        wait "$term_pid" 2>/dev/null || true
        die "pongoterm exited before bootx handoff"
    fi
    if ! usb_has '"USB Product Name" = "PongoOS USB Device"'; then
        echo '[4/4] bootx sent; PongoOS USB disconnected'
        kill "$term_pid" 2>/dev/null || true
        wait "$term_pid" 2>/dev/null || true
        trap - EXIT
        exit 0
    fi
    sleep 1
done

die "PongoOS did not leave USB after bootx"
