# =============================================================================
# Crystal Godot Template Makefile
# =============================================================================

# Platform and OS detection
ifeq ($(OS),Windows_NT)
	PLATFORM        = windows
	SO_EXT          = dll
	EXE_EXT         = .exe
	GODOT           ?= $(if $(wildcard ./godot.exe),./godot.exe,$(if $(wildcard ../godot.exe),../godot.exe,godot.exe))
	LINK_FLAGS      ?= /DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init
else
	UNAME_S := $(shell uname -s 2>/dev/null)
	ifeq ($(UNAME_S),Darwin)
		PLATFORM        = macos
		SO_EXT          = dylib
		EXE_EXT         =
		GODOT           ?= $(if $(wildcard ./godot),./godot,$(if $(wildcard ../godot),../godot,godot))
		LINK_FLAGS      ?= -dynamiclib
	else
		PLATFORM        = linux
		SO_EXT          = so
		EXE_EXT         =
		GODOT           ?= $(if $(wildcard ./godot),./godot,$(if $(wildcard ../godot),../godot,godot))
		LINK_FLAGS      ?= -shared
	endif
endif

ENTRY        ?= src/main.cr
LAPIS        ?= $(if $(wildcard ../bin/lapis$(EXE_EXT)),../bin/lapis$(EXE_EXT),lapis$(EXE_EXT))

BIN_DIR       = bin
GAME_LIB      = $(BIN_DIR)/game.$(SO_EXT)
GAME_EXE      = $(BIN_DIR)/game$(EXE_EXT)
BRIDGE_SRC    = ../bin/crystal_bridge.$(SO_EXT)
SOURCE_DIR    = $(if $(wildcard ../src),../src,$(if $(wildcard lib/libgodot/src),lib/libgodot/src,lib))

# Backward-compatibility alias
GAME_DLL      = $(GAME_LIB)

CRYSTAL_FLAGS =
ifeq ($(RELEASE), 1)
	CRYSTAL_FLAGS += --release
endif

.PHONY: all game_dll game-dll game_exe game-exe package_game package-game deps bridge extension_list addons project_bindings project-bindings bindings rebuild export export_release export-release run editor run_editor run-editor test spec setup_dev setup-dev clean help

all: dirs deps bridge extension_list addons project_bindings game_dll game_exe
	@echo ===================================================================
	@echo   Template game library and playable executable built successfully!
	@echo ===================================================================

dirs:
	@$(LAPIS) dirs

deps: dirs
	@$(LAPIS) deps -t $(BIN_DIR)

bridge: dirs
	@$(LAPIS) sync

extension_list: dirs
	@$(LAPIS) sync

addons:
	@$(LAPIS) sync --addons-only

project_bindings project-bindings: dirs
	@echo [Template] Dumping project custom GDScript and plugin nodes...
	@$(LAPIS) bind project -p .

bindings: project_bindings

game_dll game-dll: dirs deps bridge extension_list addons project_bindings
	@echo [Template] Compiling game.$(SO_EXT) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s $(SOURCE_DIR)
	@$(LAPIS) sync

game_exe game-exe: dirs deps bridge extension_list addons game_dll
	@echo [Template] Packaging complete playable game executable...
	@$(LAPIS) package game -p . -n $(or $(NAME),game) $(if $(filter 1,$(RELEASE)),-r,)

package_game package-game: all
	@echo [Template] Packaging playable standalone game...
	@$(LAPIS) package game -p . -n $(or $(NAME),game) $(if $(filter 1,$(RELEASE)),-r,) $(if $(or $(TARGET_DIR),$(EXPORT_DIR)),-t "$(or $(TARGET_DIR),$(EXPORT_DIR))",) $(if $(filter 1,$(FORCE)),-f,)

run: all
	@echo [Template] Running project with Godot...
	$(GODOT) --path .

editor: all
	@echo [Template] Opening project in Godot Editor...
	$(GODOT) --editor --path .

run_editor run-editor: all
	@$(LAPIS) editor -p . $(if $(or $(QUIT),$(QUIT_AFTER)),--quit-after $(or $(QUIT),$(QUIT_AFTER)),)

setup_dev setup-dev:
	@$(LAPIS) setup $(if $(VERSION),-v "$(VERSION)",)

clean:
	@$(LAPIS) clean

rebuild: clean all

export: all
	@echo [Template] Exporting project to export/ directory...
	@$(LAPIS) package game -p . -n $(or $(NAME),game) -t $(or $(TARGET_DIR),export) -f

export_release export-release: dirs deps bridge extension_list addons project_bindings
	@echo [Template] Exporting optimized release project to export/ directory...
	@$(LAPIS) package game -p . -n $(or $(NAME),game) -t $(or $(TARGET_DIR),export) -r -f

test spec:
	@echo [Template] Running Crystal specifications...
	@crystal spec

help:
	@echo ===================================================================
	@echo   LibGodot Template - Build and Export Commands
	@echo ===================================================================
	@echo   make                Build game library, runnable executable, and sync
	@echo   make rebuild        Clean and rebuild all artifacts
	@echo   make game-dll       Compile game shared library (game.$(SO_EXT))
	@echo   make game-exe       Package playable game executable into bin/
	@echo   make package-game   Package standalone playable game
	@echo   make export         Export standalone game package to export/
	@echo   make export-release Export release optimized game package to export/
	@echo   make test           Run Crystal specifications (spec/ and spec/editor/)
	@echo   make run            Launch game in Godot
	@echo   make editor         Open project in Godot Editor
	@echo   make run-editor     Launch editor with diagnostics
	@echo   make setup-dev      Download and install Godot engine
	@echo   make clean          Remove built binaries and export directories
	@echo ===================================================================
