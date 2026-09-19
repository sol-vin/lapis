# =============================================================================
# Crystal LibGodot Test Suite Makefile
# =============================================================================

# Platform and OS detection
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
TESTS_EXE     = $(BIN_DIR)/tests$(EXE_EXT)
BRIDGE_SRC    = ../bin/crystal_bridge.$(SO_EXT)

# Backward-compatibility alias
GAME_DLL      = $(GAME_LIB)
GAME_EXE      = $(TESTS_EXE)

CRYSTAL_FLAGS =
ifeq ($(RELEASE), 1)
	CRYSTAL_FLAGS += --release
endif

.PHONY: all game_dll game-dll game_exe game-exe package_game package-game package_tests package-tests standalone spec deps bridge extension_list addons bindings project_bindings project-bindings rebuild export export_release export-release run editor run_editor run-editor run_test run-test clean help

all: dirs deps bridge extension_list addons game_dll
	@echo ===================================================================
	@echo   Test Suite game library built successfully!
	@echo ===================================================================

bindings project_bindings project-bindings:
	@echo [API] Updating test project node bindings...
	@$(LAPIS) bind project -p .

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
	@echo [Test] Compiling game.$(SO_EXT) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s ../src
	@$(LAPIS) sync

spec:
	@echo [Spec] Running Crystal specifications in spec/...
	crystal spec

standalone game_exe game-exe: dirs deps bridge extension_list addons game_dll
	@echo [Test] Packaging standalone test runner executable...
	@$(LAPIS) package game -p . -n tests $(if $(filter 1,$(RELEASE)),-r,) -f --portable

package_game package-game: dirs deps bridge extension_list addons game_dll
	@echo [Test] Packaging playable standalone test suite...
	@$(LAPIS) package game -p . -n tests $(if $(filter 1,$(RELEASE)),-r,) $(if $(or $(TARGET_DIR),$(EXPORT_DIR)),-t "$(or $(TARGET_DIR),$(EXPORT_DIR))",) -f $(if $(or $(filter 1,$(PORTABLE)),$(filter 1,$(EMBED))),--portable,)

package_tests package-tests: standalone
	@echo [Test] Packaging standalone test runner archive...
	@$(LAPIS) package tests $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(ZIP_NAME),-o "$(ZIP_NAME)",) $(if $(filter 1,$(RELEASE)),-r,)

run: all
	@echo [Test] Running test suite with Godot...
	$(GODOT) --path .

editor: all
	@echo [Test] Opening test suite in Godot Editor...
	$(GODOT) --editor --path .

run_editor run-editor: all
	@$(LAPIS) editor -p . $(if $(or $(QUIT),$(QUIT_AFTER)),--quit-after $(or $(QUIT),$(QUIT_AFTER)),)

run_test run-test: all
ifeq ($(or $(filter 1,$(INTERACTIVE)),$(filter 1,$(UI))),1)
	@echo Launching Crystal LibGodot Interactive Test Runner...
	$(GODOT) --path . $(ARGS)
else
	@$(LAPIS) test $(if $(filter 1,$(SKIP_SPECS)),--skip-specs,) $(if $(filter 1,$(SKIP_TOOL_TESTS)),--skip-tool-tests,) $(if $(filter 1,$(SKIP_RUNTIME_TESTS)),--skip-runtime-tests,)
endif

clean:
	@$(LAPIS) clean

rebuild: clean all

export: all
	@echo [Test] Exporting test project to export/ directory...
	@$(LAPIS) package game -p . -n tests -t $(or $(TARGET_DIR),export) -f

export_release export-release: dirs deps bridge extension_list addons
	@echo [Test] Exporting optimized release test project to export/ directory...
	@$(LAPIS) package game -p . -n tests -t $(or $(TARGET_DIR),export) -r -f

help:
	@echo ===================================================================
	@echo   LibGodot Test Suite - Build and Export Commands
	@echo ===================================================================
	@echo   make                Build test project and dependencies
	@echo   make rebuild        Clean and rebuild all artifacts
	@echo   make game-dll       Compile test shared library (game.$(SO_EXT))
	@echo   make standalone     Package standalone test runner into bin/
	@echo   make package-tests  Package standalone test runner archive
	@echo   make export         Export standalone test package to export/
	@echo   make export-release Export release optimized test package to export/
	@echo   make run            Launch test suite in Godot
	@echo   make editor         Open test suite in Godot Editor
	@echo   make run-test       Execute test suite
	@echo   make spec           Run Crystal specifications in spec/
	@echo   make clean          Remove built binaries and export directories
	@echo ===================================================================
