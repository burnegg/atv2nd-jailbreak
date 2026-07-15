PYTHON ?= python3
COMPONENT_ROOT ?= components
ARTIFACTS ?= artifacts
JOBS ?= 8
PICO_SDK_PATH ?=
IBSS_INPUT ?=

.PHONY: verify build-usbliter8 build-jbinit build-pongo build-yolodfu artifacts clean

verify:
	$(PYTHON) tools/verify_components.py --component-root "$(COMPONENT_ROOT)"

build-usbliter8: verify
	@test -n "$(PICO_SDK_PATH)" || { echo "set PICO_SDK_PATH" >&2; exit 2; }
	cmake -S "$(COMPONENT_ROOT)/usbliter8" -B "$(COMPONENT_ROOT)/usbliter8/build" \
		-DPICO_SDK_PATH="$(PICO_SDK_PATH)" \
		-DPICO_BOARD=waveshare_rp2350_usb_a \
		-DT8020_TRAMPOLINE_PRESERVE=1
	cmake --build "$(COMPONENT_ROOT)/usbliter8/build" -j$(JOBS)

build-jbinit: verify
	# hfsplus and dmg-bin share one CMake tree and must not be primed in parallel.
	$(MAKE) -C "$(COMPONENT_ROOT)/jbinit" -j1 tools
	$(MAKE) -C "$(COMPONENT_ROOT)/jbinit" -j$(JOBS)

build-pongo: verify
	$(MAKE) -C "$(COMPONENT_ROOT)/PongoOS" -j$(JOBS) \
		PONGO_SRAM_BASE=0x19c000000 all

build-yolodfu: verify
	$(MAKE) -C "$(COMPONENT_ROOT)/yolodfu" -j$(JOBS) all

artifacts: build-jbinit build-pongo build-yolodfu
	@test -n "$(IBSS_INPUT)" || { echo "set IBSS_INPUT" >&2; exit 2; }
	mkdir -p "$(ARTIFACTS)"
	$(MAKE) -C "$(COMPONENT_ROOT)/yolodfu" patch \
		IBSS_INPUT="$(IBSS_INPUT)" \
		PATCHED_IBSS="$(abspath $(ARTIFACTS))/ibss.yolodfu.bin"
	$(MAKE) -C "$(COMPONENT_ROOT)/yolodfu" container \
		PONGO_INPUT="$(abspath $(COMPONENT_ROOT)/PongoOS/build/Pongo.bin)" \
		PONGO_CONTAINER="$(abspath $(ARTIFACTS))/pongo-container.bin"
	cp "$(COMPONENT_ROOT)/jbinit/src/binpack.dmg" "$(ARTIFACTS)/binpack.dmg"

clean:
	rm -rf "$(ARTIFACTS)"
