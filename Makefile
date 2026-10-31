ZIRAN ?= ziran
LOCK_FLAGS := $(if $(wildcard ziran.local.toml),,--locked)
# `ziran tool gamekit` passes the game project's toolchain as ZIRAN_DIR.
ZIRAN_DIR ?= $(shell $(ZIRAN) pkg path ziran $(LOCK_FLAGS))
CRYPTO_DIR = $(shell $(ZIRAN) pkg path crypto $(LOCK_FLAGS))
ZI2C = $(ZIRAN_DIR)/build/bin/zi2c
TOOL_SOURCES = tools/gamekit.zi tools/gamekit_pack.zi src/gamekit_contract.zi
CLEAN_ENV = env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY -u DBUS_SESSION_BUS_ADDRESS

.PHONY: all test check contract-test profile-test pack-test fixture-test
all: build/bin/gamekit

build/bin/gamekit: $(TOOL_SOURCES) Makefile ziran.lock
	test -x $(ZI2C) || $(MAKE) -C $(ZIRAN_DIR) all BUILD_DIR=build
	rm -rf build/tool
	CC=$${CC:-cc} $(ZI2C) --exe --root tools --module-path src --module-path $(ZIRAN_DIR)/std \
		--module-path crypto=$(CRYPTO_DIR)/src --entry gamekit:main -o build/tool tools/gamekit.zi
	mkdir -p build/bin
	cp build/tool/gamekit build/bin/gamekit.tmp && mv build/bin/gamekit.tmp $@

# The library modules a game or host imports.
check:
	$(ZIRAN) check --project $(LOCK_FLAGS)

test: check contract-test profile-test pack-test fixture-test
	$(ZIRAN) fmt --check src/*.zi tools/*.zi tests/*.zi tests/fixture-game/src/*.zi tests/fixture-game/tools/*.zi

# The contract matches standards/game-v1.json and the host's locale lookup.
contract-test:
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --exe --entry contract_test:main \
		-o build/contract-test tests/contract_test.zi
	cd tests && $(CLEAN_ENV) ../build/contract-test/contract_test

# The shared profile record and its limits. Records are host values, so the
# test links the runtime's bundle host.
profile-test:
	rm -rf build/profile-test
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --entry profile_test:main \
		-o build/profile-test/c tests/profile_test.zi
	$${CC:-cc} -std=c11 -O1 -Wno-main -I$(ZIRAN_DIR)/include -Ibuild/profile-test/c build/profile-test/c/*.c \
		$(ZIRAN_DIR)/build/libziran.a -lm -lpthread -o build/profile-test/profile_test
	$(CLEAN_ENV) build/profile-test/profile_test

# Locale generation, exclusions and add-on links, on a staged copy.
pack-test:
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --exe --entry pack_test:main \
		-o build/pack-test tests/pack_test.zi
	$(CLEAN_ENV) build/pack-test/pack_test tests/fixture-game build/pack-test/work

# `ziran tool gamekit pack` turns the fixture game into checked .zx apps.
# The checker opens them with the runtime's bundle loader, so it links it.
fixture-test: build/bin/gamekit
	rm -rf build/fixture-test/c
	$(ZIRAN) build --project $(LOCK_FLAGS) --target=c --entry fixture_test:main \
		-o build/fixture-test/c tests/fixture_test.zi
	$${CC:-cc} -std=c11 -O1 -Wno-main -I$(ZIRAN_DIR)/include -Ibuild/fixture-test/c build/fixture-test/c/*.c \
		$(ZIRAN_DIR)/build/libziran.a -lm -lpthread -o build/fixture-test/fixture_test
	$(CLEAN_ENV) build/fixture-test/fixture_test $(CURDIR) build/fixture-test/game
