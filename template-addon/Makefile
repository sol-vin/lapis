# =============================================================================
# Crystal Godot Addon Template Makefile
# =============================================================================

ADDON_NAME      ?= crystal_addon
ADDON_DIR       = addons/$(ADDON_NAME)
ADDON_BIN_DIR   = $(ADDON_DIR)/bin

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

ENTRY           ?= src/main.cr
LAPIS           ?= $(if $(wildcard ./bin/lapis$(EXE_EXT)),./bin/lapis$(EXE_EXT),$(if $(wildcard ../bin/lapis$(EXE_EXT)),../bin/lapis$(EXE_EXT),$(if $(wildcard ../../bin/lapis$(EXE_EXT)),../../bin/lapis$(EXE_EXT),$(if $(wildcard ./lib/lapis/bin/lapis$(EXE_EXT)),./lib/lapis/bin/lapis$(EXE_EXT),lapis$(EXE_EXT)))))
GAME_LIB        = $(ADDON_BIN_DIR)/game.$(SO_EXT)
BRIDGE_SRC      = ../bin/crystal_bridge.$(SO_EXT)
SOURCE_DIR      = $(if $(wildcard ../src),../src,lib)

CRYSTAL_FLAGS   =
ifeq ($(strip $(RELEASE)),1)
	CRYSTAL_FLAGS += --release
endif

.PHONY: all build deps bridge extension_list addons project_bindings project-bindings bindings package package_addon package-addon export export_release export-release rebuild run editor run_editor run-editor test spec setup_dev setup-dev clean help

all: dirs deps bridge extension_list addons project_bindings build
	@echo ===================================================================
	@echo   Crystal Godot Addon '$(ADDON_NAME)' built successfully!
	@echo   Run 'make editor' to test in editor or 'make package' to create zip.
	@echo ===================================================================

dirs:
	@$(LAPIS) dirs

deps: dirs
	@$(LAPIS) deps -t $(ADDON_BIN_DIR)

bridge: dirs
	@$(LAPIS) sync

extension_list: dirs
	@$(LAPIS) sync

addons: dirs
	@$(LAPIS) sync --addons-only

project_bindings project-bindings: dirs
	@echo [Addon] Dumping project custom GDScript and plugin nodes...
	@$(LAPIS) bind project -p .

bindings: project_bindings

build: dirs deps bridge extension_list addons project_bindings
	@echo [Addon] Compiling $(GAME_LIB) from $(ENTRY)...
	@$(LAPIS) build -e $(ENTRY) -o $(GAME_LIB) -l '$(LINK_FLAGS)' $(if $(filter 1,$(RELEASE)),-r,) -s $(SOURCE_DIR) --flags "-Dlibgodot_addon"
	@$(LAPIS) sync

package package_addon package-addon: all
	@echo [Addon] Packaging distributable zip for '$(ADDON_NAME)'...
	@$(LAPIS) package addon -p . -n $(ADDON_NAME) $(if $(TARGET_DIR),-t "$(TARGET_DIR)",)

export: package

export_release export-release:
	@echo [Addon] Packaging release optimized distributable zip for '$(ADDON_NAME)'...
	@$(MAKE) package RELEASE=1

rebuild: clean all

editor: all
	@echo [Addon] Launching Godot Editor to test addon...
	$(GODOT) --editor --path .

run: all
	@echo [Addon] Running Godot project with addon...
	$(GODOT) --path .

run_editor run-editor: all
	@$(LAPIS) editor -p . $(if $(or $(QUIT),$(QUIT_AFTER)),--quit-after $(or $(QUIT),$(QUIT_AFTER)),)

setup_dev setup-dev:
	@$(LAPIS) setup $(if $(VERSION),-v "$(VERSION)",)

clean:
	@$(LAPIS) clean

test spec:
	@echo [Addon] Running Crystal specifications...
	@crystal spec

help:
	@echo ===================================================================
	@echo   Lapis Addon Template - Build and Export Commands
	@echo ===================================================================
	@echo   make                Build addon library and sync dependencies
	@echo   make build          Compile addon Crystal library (game.$(SO_EXT))
	@echo   make project-bindings Generate typed Crystal wrappers for GDScript nodes
	@echo   make package        Create redistributable zip in dist/
	@echo   make export-release Build optimized release zip in dist/
	@echo   make test           Run Crystal specifications (spec/ and spec/editor/)
	@echo   make editor         Launch Godot Editor with addon loaded
	@echo   make run            Run local project with Godot
	@echo   make setup-dev      Download and install Godot engine
	@echo   make clean          Remove built binaries and distribution zips
	@echo ===================================================================
