# =============================================================================
# LibGodot for Crystal - Root Makefile
# =============================================================================
#
# Builds the complete LibGodot Crystal toolchain, editor test suite, and examples:
#   - crystal_bridge.dll (GDExtension C++ loader bridge)
#   - game.dll (Crystal game library for Godot GDExtension host/editor)
#   - game.exe (Crystal standalone executable for LibGodot host paradigm)
#   - Syncs binaries & runtime DLLs to bin/, test/bin/, template/bin/, and examples/*/bin/
#
# Usage:
#   make               - Build everything (bridge, test, examples, template, sync & verify)
#   make bridge        - Build bin/crystal_bridge.dll from C++ source
#   make test_project  - Build test/bin/game.dll test suite project
#   make examples      - Build all example projects in examples/
#   make template      - Build template project
#   make game_dll      - Build and sync game.dll across all targets
#   make deps          - Copy Crystal runtime DLLs (gc, iconv, pcre2)
#   make sync          - Sync compiled binaries from bin/ to all consumer projects
#   make engine        - Recompile Godot engine shared library (libgodot.dll) via SCons
#   make test          - Run Crystal specs and Godot headless smoke tests
#   make docs          - Generate HTML API documentation
#   make run           - Run editor test project with godot.exe
#   make editor        - Open editor test project in Godot editor
#   make clean         - Clean built artifacts (retains libgodot.dll)
#   make help          - Display this help message
# =============================================================================

# Tool configuration
CRYSTAL      ?= crystal
CXX          ?= g++
SCONS        ?= scons
GODOT        ?= ./godot.exe
ENTRY        ?= test/src/main.cr
SCONS_JOBS   ?= 7

# Platform and OS detection
ifeq ($(OS),Windows_NT)
	PLATFORM        = windows
	SO_EXT          = dll
	EXE_EXT         = .exe
	GODOT           ?= ./godot.exe
	CXXFLAGS        ?= -std=c++17 -O2 -g -I rsrc -I src/bridge -static -static-libgcc -static-libstdc++
	LINK_FLAGS      ?= /DLL /ENTRY:_DllMainCRTStartup /EXPORT:crystal_godot_init
else
	UNAME_S := $(shell uname -s 2>/dev/null)
	ifeq ($(UNAME_S),Darwin)
		PLATFORM        = macos
		SO_EXT          = dylib
		EXE_EXT         =
		GODOT           ?= ./godot
		CXX             ?= clang++
		CXXFLAGS        ?= -std=c++17 -O2 -fPIC -I rsrc -I src/bridge
		LINK_FLAGS      ?= -dynamiclib -Wl,-exported_symbol,_crystal_godot_init
	else
		PLATFORM        = linux
		SO_EXT          = so
		EXE_EXT         =
		GODOT           ?= ./godot
		CXX             ?= g++
		CXXFLAGS        ?= -std=c++17 -O2 -fPIC -I rsrc -I src/bridge
		LINK_FLAGS      ?= -shared
	endif
endif

# Optional release mode: make RELEASE=1
CRYSTAL_FLAGS =
ifeq ($(RELEASE), 1)
	CRYSTAL_FLAGS += --release
	CXXFLAGS      += -DLIBGODOT_RELEASE=1 -DNDEBUG
	export RELEASE
endif

# Output artifacts
BIN_DIR          = bin
TEST_BIN_DIR     = test/bin
TEMPLATE_BIN_DIR = template/bin
EXAMPLES_DIR     = examples
LAPIS            = $(BIN_DIR)/lapis$(EXE_EXT)
BRIDGE_LIB       = $(BIN_DIR)/crystal_bridge.$(SO_EXT)
PLUGIN_LIB       = $(BIN_DIR)/plugin.$(SO_EXT)
PLUGIN_ENTRY     ?= src/editor/plugin.cr
GAME_LIB         = $(BIN_DIR)/game.$(SO_EXT)
GAME_EXE         = $(BIN_DIR)/game$(EXE_EXT)
LIBGODOT_LIB     = $(BIN_DIR)/libgodot.$(SO_EXT)

# Aliases for backwards compatibility
BRIDGE_DLL       = $(BRIDGE_LIB)
PLUGIN_DLL       = $(PLUGIN_LIB)
GAME_DLL         = $(GAME_LIB)
LIBGODOT_DLL     = $(LIBGODOT_LIB)

.PHONY: all lapis install uninstall bridge plugin test_project test_standalone package_installer package-installer windows_installer windows-installer installer package_tests package-tests package_lapis package-lapis package_deb package-deb package_template package-template package_template_addon package-template-addon package_examples package-examples package_addon package-addon package_all package-all package_release package-release package_perf package-perf package_game package-game new_addon new-addon new_example new-example setup_dev setup-dev run_editor run-editor run_test run-test run_ci_local run-ci-local ci-local ci export_templates export-templates recompile_addons recompile-addons verify_editor verify-editor test_wsl test-wsl report_android report-android examples examples_exe template template_addon perf perf_standalone perf_run perf_editor game_dll game_exe android package_android generate dump_api project_bindings deps addons sync engine spec spec_cli spec-cli test_cli test-cli test tests debug debug_editor debug-editor docs run editor clean help

# Compile Lapis CLI toolchain if not present or source changed
$(LAPIS): $(wildcard tools/lapis/src/**/*.cr) $(wildcard tools/lapis/src/*.cr) $(wildcard tools/lapis/*.yml) $(wildcard template/**/*) $(wildcard template-addon/**/*) $(wildcard addons/crystal_integration/*) shard.yml godot-version.yml
	@echo [Lapis] Compiling Lapis toolchain ($(LAPIS))...
ifeq ($(PLATFORM),windows)
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) --static tools/lapis/src/lapis.cr -o $(LAPIS)
else
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) tools/lapis/src/lapis.cr -o $(LAPIS)
endif

lapis: $(LAPIS)

# Install Lapis CLI toolchain globally to system/user PATH
install: $(LAPIS)
	@$(LAPIS) install $(if $(INSTALL_DIR),--dir "$(INSTALL_DIR)",) $(if $(PREFIX),--prefix "$(PREFIX)",) $(if $(filter 1,$(FORCE)),--force,)

# Uninstall Lapis CLI toolchain globally
uninstall: $(LAPIS)
	@$(LAPIS) install --uninstall $(if $(INSTALL_DIR),--dir "$(INSTALL_DIR)",) $(if $(PREFIX),--prefix "$(PREFIX)",)

# Default target: compile bridge, plugin, test project, standalone runner, examples, template, template_addon, perf, sync DLLs, run test suite, and Windows installer
all: dirs deps bridge plugin addons dummy_addons test_project test_standalone examples template template_addon perf perf_standalone sync test $(if $(filter windows,$(PLATFORM)),$(if $(filter 1,$(SKIP_INSTALLER)),,package_installer),)
	@echo ===================================================================
	@echo   LibGodot Crystal library build completed successfully!
	@echo   Run 'make run' to launch test runner or 'make editor' for editor.
	@echo ===================================================================

# Ensure output directories exist
dirs: $(LAPIS)
	@$(LAPIS) dirs

# Compile C++ GDExtension bridge and sync to consumer projects
bridge: dirs src/bridge/crystal_bridge.cpp $(wildcard src/bridge/*.hpp) $(wildcard src/bridge/*.h)
	@echo [Bridge] Compiling GDExtension bridge $(BRIDGE_LIB)...
ifeq ($(PLATFORM),macos)
	$(CXX) -dynamiclib $(CXXFLAGS) src/bridge/crystal_bridge.cpp -o $(BRIDGE_LIB)
else
	$(CXX) -shared $(CXXFLAGS) src/bridge/crystal_bridge.cpp -o $(BRIDGE_LIB)
endif
	@$(LAPIS) sync

# Compile Crystal editor integration plugin library (plugin.dll)
plugin: dirs deps bridge
	@echo [Plugin] Compiling Crystal editor integration plugin $(PLUGIN_LIB)...
	@$(LAPIS) build --entry $(PLUGIN_ENTRY) --output $(PLUGIN_LIB) --link-flags "$(LINK_FLAGS)" $(if $(filter 1,$(RELEASE)),--release,) --flags "-Dlibgodot_addon"
	@$(LAPIS) sync

# Synchronize addons across root, test, template, and examples
addons: dirs
	@$(LAPIS) sync --addons-only

# Build dummy test addons for multi-addon isolation stress tests
dummy_addons: dirs deps bridge
	@$(LAPIS) build addons $(if $(filter 1,$(RELEASE)),--release,)
	@$(LAPIS) sync

# Build test project
test_project: dirs deps bridge addons dummy_addons
	@echo [Test] Building test suite project...
	$(MAKE) -C test RELEASE=$(RELEASE)

# Build standalone test project executable
test_standalone: dirs deps bridge addons dummy_addons
	@echo [Test] Building standalone test suite executable...
	$(MAKE) -C test standalone RELEASE=$(RELEASE)

# Build all showcase examples in examples/
examples: dirs deps bridge addons
	@echo [Examples] Building all projects in $(EXAMPLES_DIR)...
	@$(LAPIS) build examples $(if $(filter 1,$(RELEASE)),--release,)

# Build standalone executables for all projects in examples/
examples_exe: dirs deps bridge addons
	@echo [Examples] Building standalone executables for all projects in $(EXAMPLES_DIR)...
	@$(LAPIS) build examples --exe $(if $(filter 1,$(RELEASE)),--release,)

# Build starter game template project
template: dirs deps bridge addons
	@echo [Template] Building template project...
	$(MAKE) -C template RELEASE=$(RELEASE)

# Build addon starter template project
template_addon: dirs deps bridge addons
	@echo [TemplateAddon] Building template-addon project...
	$(MAKE) -C template-addon RELEASE=$(RELEASE)

# Dedicated performance stress testing project
perf: dirs deps bridge addons
	@echo [Performance] Building performance stress benchmark...
	$(MAKE) -C performance RELEASE=$(RELEASE)

# Build standalone performance suite executable
perf_standalone: dirs deps bridge addons
	@echo [Performance] Building standalone performance benchmark executable...
	$(MAKE) -C performance standalone RELEASE=$(RELEASE)

# Package standalone test suite into tests-<platform>.zip
package_tests package-tests: test_standalone
	@echo [Package] Packaging standalone test suite...
	@$(LAPIS) package tests $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(ZIP_NAME),-o "$(ZIP_NAME)",) $(if $(filter 1,$(RELEASE)),-r,)

# Package standalone performance benchmark into perf-<platform>.zip
package_perf package-perf: perf_standalone
	@echo [Package] Packaging standalone performance benchmark...
	@$(LAPIS) package perf $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(or $(ARCHIVE_NAME),$(ZIP_NAME)),-o "$(or $(ARCHIVE_NAME),$(ZIP_NAME))",) $(if $(filter 1,$(RELEASE)),-r,)

# Package starter template project into template-project.zip
package_template package-template: template
	@echo [Package] Packaging starter template project...
	@$(LAPIS) package template $(if $(ZIP_NAME),-o "$(ZIP_NAME)",) $(if $(or $(filter 1,$(BUNDLE)),$(filter 1,$(BUNDLE_BINARIES))),--bundle-binaries,)

# Package addon starter template into template-addon-project.zip
package_template_addon package-template-addon: template_addon
	@echo [Package] Packaging addon starter template...
	@$(LAPIS) package template-addon $(if $(ZIP_NAME),-o "$(ZIP_NAME)",) $(if $(or $(filter 1,$(BUNDLE)),$(filter 1,$(BUNDLE_BINARIES))),--bundle-binaries,)

# Package standalone examples (with source + installed scripts + binaries) into examples-<platform>.zip
package_examples package-examples: examples
	@echo [Package] Packaging standalone examples...
	@$(LAPIS) package examples $(if $(ZIP_NAME),-o "$(ZIP_NAME)",)

# Package official crystal_integration addon into godot-crystal-addon.zip
package_addon package-addon: plugin bridge
	@echo [Package] Packaging official Crystal integration addon...
	@$(LAPIS) package addon $(if $(PLATFORM),--platform "$(PLATFORM)",) $(if $(ZIP_NAME),-o "$(ZIP_NAME)",) $(if $(TARGET_DIR),-t "$(TARGET_DIR)",)

# Package standalone Lapis toolchain into lapis-<platform>.zip / tar.gz
package_lapis package-lapis: $(LAPIS)
	@echo [Package] Packaging standalone Lapis toolchain...
	@$(LAPIS) package lapis $(if $(PLATFORM),--platform "$(PLATFORM)",) $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(or $(ARCHIVE_NAME),$(ZIP_NAME)),-o "$(or $(ARCHIVE_NAME),$(ZIP_NAME))",) $(if $(filter 1,$(RELEASE)),-r,)

# Package Lapis Debian (.deb) package
package_deb package-deb: $(LAPIS)
ifneq ($(PLATFORM),linux)
	@echo Error: Debian package (.deb) can only be built on Linux (current platform: $(PLATFORM)).
	@exit 1
else
	@echo [Package] Packaging Lapis Debian package...
	@$(LAPIS) package deb $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(or $(DEB_NAME),$(OUTPUT)),-o "$(or $(DEB_NAME),$(OUTPUT))",) $(if $(VERSION),-v "$(VERSION)",) $(if $(ARCH),-a "$(ARCH)",)
endif

# Package Windows Inno Setup installer executable (.exe)
package_installer package-installer windows_installer windows-installer installer: $(LAPIS)
ifneq ($(PLATFORM),windows)
	@echo Error: Windows installer (.exe) can only be built on Windows (current platform: $(PLATFORM)).
	@exit 1
else
	@echo [Package] Packaging Windows installer executable...
	@$(LAPIS) package windows-installer $(if $(TARGET_DIR),-t "$(TARGET_DIR)",) $(if $(or $(INSTALLER_NAME),$(OUTPUT)),-o "$(or $(INSTALLER_NAME),$(OUTPUT))",) $(if $(VERSION),-v "$(VERSION)",) $(if $(filter 1,$(RELEASE)),-r,)
endif

# Package all release archives and checksums into bin/release_dist/
package_all package-all package_release package-release:
	@echo [Package] Packaging all release archives into $(or $(OUTPUT_DIR),$(TARGET_DIR),bin/release_dist)...
	@$(LAPIS) package release $(if $(or $(OUTPUT_DIR),$(TARGET_DIR)),-t "$(or $(OUTPUT_DIR),$(TARGET_DIR))",) $(if $(filter 1,$(SKIP_TESTS)),--skip-tests,) $(if $(filter 1,$(SKIP_PERF)),--skip-perf,)

# Package playable standalone Godot game (binary + PCK + runtime DLLs)
package_game package-game:
	@echo [Package] Packaging playable standalone Godot game...
	@$(LAPIS) package game $(if $(or $(PROJECT),$(PATH)),-p "$(or $(PROJECT),$(PATH))",) $(if $(NAME),-n "$(NAME)",) $(if $(filter 1,$(RELEASE)),-r,) $(if $(or $(TARGET_DIR),$(EXPORT_DIR)),-t "$(or $(TARGET_DIR),$(EXPORT_DIR))",) $(if $(filter 1,$(FORCE)),-f,)

# Scaffold a new compiled Crystal GDExtension addon project
new_addon new-addon:
ifeq ($(strip $(NAME)),)
	@echo Error: 'NAME' parameter is required.
	@echo Usage: make new-addon NAME=my_addon [DIR=path/to/addon] [AUTHOR="Author"] [DESC="Description"]
	@exit 1
else
	@echo [Scaffold] Scaffolding new Crystal GDExtension Addon '$(NAME)'...
	@$(LAPIS) scaffold addon $(NAME) $(if $(or $(DIR),$(TARGET),$(TARGET_PATH)),-d "$(or $(DIR),$(TARGET),$(TARGET_PATH))",) $(if $(AUTHOR),-a "$(AUTHOR)",) $(if $(or $(DESC),$(DESCRIPTION)),--desc "$(or $(DESC),$(DESCRIPTION))",)
endif

# Scaffold a new LibGodot showcase example project
new_example new-example:
ifeq ($(strip $(NAME)),)
	@echo Error: 'NAME' parameter is required.
	@echo Usage: make new-example NAME=my_example [DIR=path/to/example]
	@exit 1
else
	@echo [Scaffold] Scaffolding new LibGodot Example '$(NAME)'...
	@$(LAPIS) scaffold example $(NAME) $(if $(or $(DIR),$(TARGET),$(TARGET_PATH)),-d "$(or $(DIR),$(TARGET),$(TARGET_PATH))",)
endif


perf_run: perf
	@echo [Performance] Launching performance stress benchmark...
	$(MAKE) -C performance run ARGS="$(ARGS)"

perf_editor: perf
	@echo [Performance] Opening performance project in Godot Editor...
	$(MAKE) -C performance editor

# Compile game_dll for all consumers and synchronize
game_dll: dirs deps bridge addons test_project examples template template_addon perf sync
	@echo [Build] All game library targets compiled and synced!

game_exe: dirs deps bridge
	@echo [Standalone] Compiling standalone game executable from $(ENTRY)...
	@$(LAPIS) build --entry $(ENTRY) --output $(GAME_EXE) $(if $(filter 1,$(RELEASE)),--release,)

# Generate Crystal bindings from Godot extension_api.json
dump_api: $(LAPIS)
	@echo [API] Dumping extension_api.json from Godot...
	@$(LAPIS) bind engine --dump

generate bind_engine: $(LAPIS)
	@echo [Generator] Generating complete Godot bindings from extension_api.json...
	@$(LAPIS) bind engine

# Generate typed Crystal bindings for project custom GDScript and plugin nodes
project_bindings bind_project: $(LAPIS)
	@echo [API] Dumping and generating typed bindings for project custom GDScript and plugin nodes...
	@$(LAPIS) bind project $(if $(PROJECT),-p $(PROJECT),-p template)

# Copy Crystal runtime dependencies and libgodot to all bin dirs
deps: dirs
	@echo [Dependencies] Ensuring runtime libraries are available in bin/, test/bin/, and template/bin/...
	@$(LAPIS) deps

# Synchronize compiled binaries and runtime dependencies to consumer projects
sync: addons
	@echo [Sync] Syncing runtime libraries and bridge to test/bin, template/bin, and examples...
	@$(LAPIS) sync

# Build Godot engine shared library from source (requires godot-src and scons)
engine:
	@echo Compiling Godot Engine shared library $(LIBGODOT_LIB) via SCons...
	$(SCONS) -C godot-src target=template_debug dev_build=yes library_type=shared_library -j$(SCONS_JOBS)
	@$(LAPIS) sync
	@echo $(LIBGODOT_LIB) updated successfully!

# Run Crystal unit specifications (test/spec and tools/lapis/spec)
spec:
	@echo [Spec] Running Phase 1a: Engine specifications (test/spec)...
	$(CRYSTAL) spec test/spec
	@echo [Spec] Running Phase 1b: Lapis CLI specifications (tools/lapis/spec)...
	$(CRYSTAL) spec tools/lapis/spec

# Run only Lapis CLI toolchain unit specifications
spec_cli spec-cli test_cli test-cli:
	@echo [Spec] Running Phase 1b: Lapis CLI specifications (tools/lapis/spec)...
	$(CRYSTAL) spec tools/lapis/spec

# Run complete test suites and verification (Crystal specs, in-editor @tool tests, standalone runner, runtime project tests, smoke tests)
test tests: test_standalone
	@$(LAPIS) test $(if $(filter 1,$(SKIP_SPECS)),--skip-specs,) $(if $(filter 1,$(SKIP_TOOL_TESTS)),--skip-tool-tests,) $(if $(filter 1,$(SKIP_RUNTIME_TESTS)),--skip-runtime-tests,)

# Unified test runner (supports interactive UI or automated suite)
run_test run-test:
ifeq ($(or $(filter 1,$(INTERACTIVE)),$(filter 1,$(UI))),1)
	@echo Launching Crystal LibGodot Interactive Test Runner...
	@$(LAPIS) run -p test
else
	@$(LAPIS) test $(if $(filter 1,$(SKIP_SPECS)),--skip-specs,) $(if $(filter 1,$(SKIP_TOOL_TESTS)),--skip-tool-tests,) $(if $(filter 1,$(SKIP_RUNTIME_TESTS)),--skip-runtime-tests,)
endif

# Run complete local CI test matrix harness
run_ci_local run-ci-local ci-local ci:
	@$(LAPIS) test

# Download and configure Godot engine binary for development
setup_dev setup-dev:
	@$(LAPIS) setup $(if $(VERSION),-v "$(VERSION)",)

# Generate offline HTML documentation
docs:
	@$(LAPIS) docs

# Launch test project using Godot
run:
	@echo Launching Crystal LibGodot Test Runner...
	@$(LAPIS) run -p test

# Launch Godot editor for test project
editor:
	@echo Opening Godot Editor for Test Project...
	@$(LAPIS) editor -p test

# Unified Godot editor launcher with shadow logging, auto-quit, and LLDB flags
run_editor run-editor:
	@$(LAPIS) editor -p "$(or $(PROJECT),$(PATH),test)" $(if $(or $(QUIT),$(QUIT_AFTER)),--quit-after $(or $(QUIT),$(QUIT_AFTER)),)

# Run project under LLDB debugger
debug:
	@echo Launching Crystal LibGodot under LLDB Debugger...
	@$(LAPIS) editor -r -p "$(or $(PROJECT),$(PATH),test)" --lldb $(if $(filter 1,$(BATCH)),--batch,)

# Open Godot Editor under LLDB debugger
debug_editor debug-editor:
	@echo Opening Godot Editor under LLDB Debugger...
	@$(LAPIS) editor -p "$(or $(PROJECT),$(PATH),test)" --lldb $(if $(or $(QUIT),$(QUIT_AFTER)),--quit-after $(or $(QUIT),$(QUIT_AFTER)),)

# Recompile all Crystal addons found across a project
recompile_addons recompile-addons:
	@$(LAPIS) build addons $(if $(filter 1,$(RELEASE)),--release,)

# Clean build artifacts (preserves libgodot.dll and runtime DLLs)
clean:
	@$(LAPIS) clean

# Display help menu
help:
	@echo =========================================================================================
	@echo   LibGodot for Crystal - Root Build and Command Reference
	@echo =========================================================================================
	@echo   CORE BUILD TARGETS:
	@echo     make                        Build bridge, test project, examples, template, sync, verify
	@echo     make bridge                 Compile C++ GDExtension bridge (bin/crystal_bridge.dll)
	@echo     make plugin                 Compile Crystal editor plugin library (bin/plugin.dll)
	@echo     make test_project           Compile test suite library (test/bin/game.dll)
	@echo     make examples               Compile all showcase projects in examples/
	@echo     make template               Compile starter game template (template/bin/game.dll)
	@echo     make template_addon         Compile addon starter template (template-addon/)
	@echo     make perf                   Compile performance stress benchmark (performance/)
	@echo     make game_dll               Compile and synchronize game.dll across all targets
	@echo     make deps                   Verify and copy runtime DLLs (gc, iconv, pcre2, libgodot)
	@echo     make sync                   Synchronize binaries and addons across consumer projects
	@echo     make clean                  Remove compiled game and bridge binaries
	@echo     make install                Install Lapis CLI globally [INSTALL_DIR=...] [PREFIX=...] [FORCE=1]
	@echo     make uninstall              Uninstall Lapis CLI globally [INSTALL_DIR=...] [PREFIX=...]
	@echo.
	@echo   SCAFFOLDING TARGETS:
	@echo     make new-addon NAME=^<n^>      Scaffold new addon [DIR=...] [AUTHOR=...] [DESC=...]
	@echo     make new-example NAME=^<n^>    Scaffold new example project [DIR=...]
	@echo.
	@echo   PACKAGING TARGETS:
	@echo     make package-game           Package playable game [PROJECT=.] [RELEASE=1] [FORCE=1]
	@echo     make package-release        Package all release archives into bin/release_dist/
	@echo     make package-installer      Package Windows Inno Setup installer executable (.exe)
	@echo     make package-deb            Package Lapis Debian package (.deb)
	@echo     make package-tests          Package standalone test runner into tests-^<platform^>.zip
	@echo     make package-template       Package starter template into template-project.zip
	@echo     make package-template-addon Package addon template into template-addon-project.zip
	@echo     make package-examples       Package examples into examples-^<platform^>.zip
	@echo     make package-addon          Package crystal_integration addon into zip
	@echo     make package-perf           Package performance benchmark into perf-^<platform^>.zip
	@echo.
	@echo   EXECUTION, TESTING AND DEBUGGING:
	@echo     make run                    Launch test suite in Godot
	@echo     make editor                 Open test suite in Godot Editor
	@echo     make run-editor             Launch editor [PROJECT=...] [LOG=...] [QUIT=...] [LLDB=1]
	@echo     make run-test               Run tests [UI=1] [SKIP_SPECS=1] [SKIP_RUNTIME_TESTS=1]
	@echo     make run-ci-local           Simulate local GitHub Actions CI matrix harness
	@echo     make test                   Run complete test suite and verification specs
	@echo     make spec                   Run headless Crystal unit specifications (test/spec)
	@echo     make debug                  Run test suite under LLDB debugger [PROJECT=...]
	@echo     make debug-editor           Open Godot Editor under LLDB debugger [PROJECT=...]
	@echo.
	@echo   ENGINE AND DEVELOPER TOOLS:
	@echo     make setup-dev              Download/setup Godot engine binary [VERSION=...]
	@echo     make export-templates       Ensure Godot export templates installed [VERSION=...]
	@echo     make recompile-addons       Recompile all Crystal addons in project [PROJECT=...]
	@echo     make verify-editor          Verify editor launch, hot-reload, clean exit [PROJECT=...]
	@echo     make test-wsl               Run Linux test suite inside WSL (Ubuntu)
	@echo     make report-android         Audit Android binaries and APK artifacts
	@echo     make dump_api               Dump extension_api.json from Godot
	@echo     make generate               Generate typed Crystal bindings from extension_api.json
	@echo     make project_bindings       Generate typed bindings for project custom GDScript
	@echo     make docs                   Generate offline HTML API documentation in docs/
	@echo =========================================================================================
