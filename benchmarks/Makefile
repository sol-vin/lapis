# =============================================================================
# Lapis Benchmarks: Crystal vs GDScript Makefile
# =============================================================================

ifeq ($(OS),Windows_NT)
	EXE_EXT := .exe
	GODOT   ?= ../godot.exe
else
	EXE_EXT :=
	GODOT   ?= ../godot
endif

CRYSTAL ?= crystal
BIN_DIR := bin
RUNNER  := $(BIN_DIR)/runner$(EXE_EXT)

CRYSTAL_FLAGS ?= --release -O3

TARGETS := $(BIN_DIR)/matmul$(EXE_EXT) \
           $(BIN_DIR)/primes$(EXE_EXT) \
           $(BIN_DIR)/bf$(EXE_EXT) \
           $(BIN_DIR)/base64$(EXE_EXT) \
           $(BIN_DIR)/json$(EXE_EXT) \
           $(BIN_DIR)/nbody$(EXE_EXT) \
           $(BIN_DIR)/binarytrees$(EXE_EXT) \
           $(BIN_DIR)/mandelbrot$(EXE_EXT) \
           $(BIN_DIR)/transform_math$(EXE_EXT) \
           $(BIN_DIR)/node_lifecycle$(EXE_EXT) \
           $(BIN_DIR)/material_resources$(EXE_EXT) \
           $(BIN_DIR)/signals$(EXE_EXT)

.PHONY: all build run chart clean help

all: build

build: $(TARGETS) $(RUNNER)
	@echo [Benchmarks] All benchmark binaries compiled successfully!

$(BIN_DIR):
	@mkdir -p $(BIN_DIR)

$(BIN_DIR)/matmul$(EXE_EXT): matmul/matmul.cr | $(BIN_DIR)
	@echo [Compile] matmul...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) matmul/matmul.cr -o $(BIN_DIR)/matmul$(EXE_EXT)

$(BIN_DIR)/primes$(EXE_EXT): primes/primes.cr | $(BIN_DIR)
	@echo [Compile] primes...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) primes/primes.cr -o $(BIN_DIR)/primes$(EXE_EXT)

$(BIN_DIR)/bf$(EXE_EXT): brainfuck/bf.cr | $(BIN_DIR)
	@echo [Compile] brainfuck...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) brainfuck/bf.cr -o $(BIN_DIR)/bf$(EXE_EXT)

$(BIN_DIR)/base64$(EXE_EXT): base64/test.cr | $(BIN_DIR)
	@echo [Compile] base64...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) base64/test.cr -o $(BIN_DIR)/base64$(EXE_EXT)

$(BIN_DIR)/json$(EXE_EXT): json/test.cr | $(BIN_DIR)
	@echo [Compile] json...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) json/test.cr -o $(BIN_DIR)/json$(EXE_EXT)

$(BIN_DIR)/nbody$(EXE_EXT): nbody/nbody.cr | $(BIN_DIR)
	@echo [Compile] nbody...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) nbody/nbody.cr -o $(BIN_DIR)/nbody$(EXE_EXT)

$(BIN_DIR)/binarytrees$(EXE_EXT): binarytrees/binarytrees.cr | $(BIN_DIR)
	@echo [Compile] binarytrees...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) binarytrees/binarytrees.cr -o $(BIN_DIR)/binarytrees$(EXE_EXT)

$(BIN_DIR)/mandelbrot$(EXE_EXT): mandelbrot/mandelbrot.cr | $(BIN_DIR)
	@echo [Compile] mandelbrot...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) mandelbrot/mandelbrot.cr -o $(BIN_DIR)/mandelbrot$(EXE_EXT)

$(BIN_DIR)/transform_math$(EXE_EXT): transform_math/transform_math.cr | $(BIN_DIR)
	@echo [Compile] transform_math...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) transform_math/transform_math.cr -o $(BIN_DIR)/transform_math$(EXE_EXT)

$(BIN_DIR)/node_lifecycle$(EXE_EXT): node_lifecycle/node_lifecycle.cr | $(BIN_DIR)
	@echo [Compile] node_lifecycle...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) node_lifecycle/node_lifecycle.cr -o $(BIN_DIR)/node_lifecycle$(EXE_EXT)

$(BIN_DIR)/material_resources$(EXE_EXT): material_resources/material_resources.cr | $(BIN_DIR)
	@echo [Compile] material_resources...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) material_resources/material_resources.cr -o $(BIN_DIR)/material_resources$(EXE_EXT)

$(BIN_DIR)/signals$(EXE_EXT): signals/signals.cr | $(BIN_DIR)
	@echo [Compile] signals...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) signals/signals.cr -o $(BIN_DIR)/signals$(EXE_EXT)

$(RUNNER): runner.cr $(wildcard src/*.cr) $(wildcard src/reporters/*.cr) | $(BIN_DIR)
	@echo [Compile] benchmark runner...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) runner.cr -o $(RUNNER)

run: build
	@$(RUNNER) -i $(or $(ITERATIONS),3)

chart: run
	@echo [Chart] Results available at results/

clean:
	@rm -rf $(BIN_DIR)/*.exe $(BIN_DIR)/*.pdb results/*.svg results/*.md results/*.html results/*.json results/*.csv
