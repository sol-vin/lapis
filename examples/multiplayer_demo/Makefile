# =============================================================================
# Lapis Multiplayer Showcase Demo Makefile
# =============================================================================

ifeq ($(OS),Windows_NT)
	PLATFORM        = windows
	SO_EXT          = dll
	EXE_EXT         = .exe
	GODOT           ?= ../../godot.exe
	LINK_FLAGS      ?= /DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init
else
	UNAME_S := $(shell uname -s 2>/dev/null)
	ifeq ($(UNAME_S),Darwin)
		PLATFORM        = macos
		SO_EXT          = dylib
		EXE_EXT         =
		GODOT           ?= ../../godot
		LINK_FLAGS      ?= -dynamiclib
	else
		PLATFORM        = linux
		SO_EXT          = so
		EXE_EXT         =
		GODOT           ?= ../../godot
		LINK_FLAGS      ?= -shared
	endif
endif

ENTRY        ?= src/main.cr
LAPIS        ?= ../../bin/lapis$(EXE_EXT)

BIN_DIR       = bin
GAME_LIB      = $(BIN_DIR)/game.$(SO_EXT)
GAME_EXE      = $(BIN_DIR)/game$(EXE_EXT)
BRIDGE_SRC    = ../../bin/crystal_bridge.$(SO_EXT)

# Backward-compatibility alias
GAME_DLL      = $(GAME_LIB)

CRYSTAL_FLAGS =
ifeq ($(RELEASE), 1)
	CRYSTAL_FLAGS += --release
endif

.PHONY: all game_dll game_exe deps bridge extension_list addons rebuild export export_release run editor clean help test

all: dirs deps bridge extension_list addons game_dll
	@echo ===================================================================
	@echo   Multiplayer Demo built successfully!
	@echo   Run 'make run' to launch interactive demo or 'make editor'.
	@echo ===================================================================

dirs:
	@$(LAPIS) dirs

deps: dirs
	@$(LAPIS) deps -t $(BIN_DIR)

bridge: dirs
	@$(LAPIS) sync

extension_list: dirs
	@$(LAPIS) sync

addons: dirs
	@$(LAPIS) sync --addons-only

game_dll: dirs deps bridge extension_list addons
	@echo [MultiplayerDemo] Compiling game.$(SO_EXT) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s ../../src
	@$(LAPIS) sync

game_exe: dirs deps bridge extension_list addons game_dll
	@echo [MultiplayerDemo] Packaging complete playable game executable...
	@$(LAPIS) package game -p . -n multiplayer_demo $(if $(filter 1,$(RELEASE)),-r,)

run: all
	@echo [MultiplayerDemo] Running Multiplayer Demo with $(GODOT)...
	$(GODOT) --path .

editor: all
	@echo [MultiplayerDemo] Opening Multiplayer Demo in Godot Editor...
	$(GODOT) --editor --path .

test: all
	@echo [MultiplayerDemo] Running automated headless multiplayer test...
	$(GODOT) --headless --path . -- --test

clean:
	@$(LAPIS) clean
	@rm -rf $(BIN_DIR) .godot

help:
	@echo ===================================================================
	@echo   Multiplayer Demo - Build and Run Commands
	@echo ===================================================================
	@echo   make all          - Build demo game library and sync dependencies
	@echo   make run          - Launch interactive demo in Godot
	@echo   make editor       - Open project in Godot Editor
	@echo   make test         - Run headless automated test cycle
	@echo   make clean        - Remove build artifacts
	@echo ===================================================================
