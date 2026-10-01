# =============================================================================
# Crystal Godot Demo Makefile
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

.PHONY: all game_dll game_exe deps bridge extension_list addons rebuild export export_release run editor clean help

all: dirs deps bridge extension_list addons game_dll game_exe
	@echo ===================================================================
	@echo   Demo game library and playable executable built successfully!
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
	@echo [Demo] Compiling game.$(SO_EXT) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s ../../src
	@$(LAPIS) sync

game_exe: dirs deps bridge extension_list addons game_dll
	@echo [Demo] Packaging complete playable game executable...
	@$(LAPIS) package game -p . -n basic_demo $(if $(filter 1,$(RELEASE)),-r,)

run: all
	@echo [Demo] Running demo with Godot...
	$(GODOT) --path .

editor: all
	@echo [Demo] Opening demo in Godot Editor...
	$(GODOT) --editor --path .

test spec:
	@echo [Demo] Running Crystal specifications...
	@crystal spec 2>/dev/null || true

docs:
	@$(LAPIS) docs

clean:
	@$(LAPIS) clean

rebuild: clean all

export: all
	@echo [Demo] Exporting demo to export/ directory...
	@$(LAPIS) package game -p . -n basic_demo -t export -f

export_release: dirs deps bridge extension_list addons
	@echo [Demo] Exporting optimized release demo to export/ directory...
	@$(LAPIS) package game -p . -n basic_demo -t export -r -f

help:
	@echo ===================================================================
	@echo   LibGodot Basic Demo - Build and Export Commands
	@echo ===================================================================
	@echo   make                Build demo library, runnable executable, and sync
	@echo   make rebuild        Clean and rebuild all artifacts
	@echo   make game_dll       Compile demo shared library (game.$(SO_EXT))
	@echo   make game_exe       Package playable demo executable into bin/
	@echo   make export         Export standalone playable demo package to export/
	@echo   make export_release Export release optimized demo package to export/
	@echo   make run            Launch demo in Godot
	@echo   make editor         Open demo in Godot Editor
	@echo   make clean          Remove built binaries and export directories
	@echo ===================================================================
