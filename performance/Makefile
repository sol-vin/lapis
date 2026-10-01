# =============================================================================
# Crystal LibGodot Performance Stress Benchmark Makefile
# =============================================================================

ifeq ($(OS),Windows_NT)
	PLATFORM        = windows
	SO_EXT          = dll
	EXE_EXT         = .exe
	GODOT           ?= ../godot.exe
	LINK_FLAGS      ?= /DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init
else
	UNAME_S := $(shell uname -s 2>/dev/null)
	ifeq ($(UNAME_S),Darwin)
		PLATFORM        = macos
		SO_EXT          = dylib
		EXE_EXT         =
		GODOT           ?= ../godot
		LINK_FLAGS      ?= -dynamiclib
	else
		PLATFORM        = linux
		SO_EXT          = so
		EXE_EXT         =
		GODOT           ?= ../godot
		LINK_FLAGS      ?= -shared
	endif
endif

ENTRY        ?= src/main.cr
LAPIS        ?= ../bin/lapis$(EXE_EXT)

BIN_DIR       = bin
GAME_LIB      = $(BIN_DIR)/game.$(SO_EXT)
BRIDGE_SRC    = ../bin/crystal_bridge.$(SO_EXT)

CRYSTAL_FLAGS =
ifeq ($(RELEASE), 1)
	CRYSTAL_FLAGS += --release
endif

.PHONY: all game_dll game-dll game_exe game-exe package package_perf package-perf package_game package-game standalone deps bridge extension_list addons run editor run_editor run-editor clean help

all: dirs deps bridge extension_list addons game_dll
	@echo ===================================================================
	@echo   Performance Benchmark library built successfully!
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

game_dll game-dll: dirs deps bridge extension_list addons
	@echo [Performance] Compiling game.$(SO_EXT) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s ../src
	@$(LAPIS) sync

standalone game_exe game-exe: dirs deps bridge extension_list addons game_dll
	@echo [Performance] Packaging standalone benchmark executable...
	@$(LAPIS) package game -p . -n "perf" $(if $(filter 1,$(RELEASE)),-r,) -f

package package_perf package-perf: standalone
	@echo [Performance] Packaging standalone benchmark archive...
	@$(LAPIS) package perf $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(or $(ARCHIVE_NAME),$(ZIP_NAME)),-o "$(or $(ARCHIVE_NAME),$(ZIP_NAME))",) $(if $(filter 1,$(RELEASE)),-r,)

package_game package-game: dirs deps bridge extension_list addons game_dll
	@echo [Performance] Packaging standalone benchmark game...
	@$(LAPIS) package game -p . -n "perf" $(if $(filter 1,$(RELEASE)),-r,) $(if $(or $(TARGET_DIR),$(EXPORT_DIR)),-t "$(or $(TARGET_DIR),$(EXPORT_DIR))",) -f

run: all
	@echo [Performance] Running Performance Stress Benchmark...
	$(GODOT) --path . $(ARGS)

editor: all
	@echo [Performance] Opening Performance project in Godot Editor...
	$(GODOT) --editor --path .

run_editor run-editor: all
	@$(LAPIS) editor -p . $(if $(or $(QUIT),$(QUIT_AFTER)),--quit-after $(or $(QUIT),$(QUIT_AFTER)),)

clean:
	@$(LAPIS) clean

help:
	@echo ===================================================================
	@echo   LibGodot Performance Benchmark - Build Commands
	@echo ===================================================================
	@echo   make                Build performance library and sync dependencies
	@echo   make game-dll       Compile game shared library (game.$(SO_EXT))
	@echo   make standalone     Package standalone benchmark executable
	@echo   make package-perf   Package benchmark archive into perf-^<platform^>.zip
	@echo   make package-game   Package standalone playable game
	@echo   make run            Launch performance benchmark in Godot
	@echo   make editor         Open performance project in Godot Editor
	@echo   make run-editor     Launch editor [LOG=...] [QUIT=...] [DEBUG=1]
	@echo   make clean          Remove built binaries and standalone executables
	@echo ===================================================================
