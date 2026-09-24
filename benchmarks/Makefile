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
           $(BIN_DIR)/signals$(EXE_EXT) \
           $(BIN_DIR)/perlin_noise$(EXE_EXT) \
           $(BIN_DIR)/simplex_noise$(EXE_EXT) \
           $(BIN_DIR)/cellular_noise$(EXE_EXT) \
           $(BIN_DIR)/surface_tool$(EXE_EXT) \
           $(BIN_DIR)/astar_2d$(EXE_EXT) \
           $(BIN_DIR)/tree_traversal$(EXE_EXT) \
           $(BIN_DIR)/image_processing$(EXE_EXT) \
           $(BIN_DIR)/transform_hierarchy$(EXE_EXT) \
           $(BIN_DIR)/node_groups$(EXE_EXT) \
           $(BIN_DIR)/vector_math_2d$(EXE_EXT) \
           $(BIN_DIR)/dictionary_ops$(EXE_EXT) \
           $(BIN_DIR)/config_file$(EXE_EXT)

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

$(BIN_DIR)/perlin_noise$(EXE_EXT): perlin_noise/perlin_noise.cr | $(BIN_DIR)
	@echo [Compile] perlin_noise...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) perlin_noise/perlin_noise.cr -o $(BIN_DIR)/perlin_noise$(EXE_EXT)

$(BIN_DIR)/simplex_noise$(EXE_EXT): simplex_noise/simplex_noise.cr | $(BIN_DIR)
	@echo [Compile] simplex_noise...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) simplex_noise/simplex_noise.cr -o $(BIN_DIR)/simplex_noise$(EXE_EXT)

$(BIN_DIR)/cellular_noise$(EXE_EXT): cellular_noise/cellular_noise.cr | $(BIN_DIR)
	@echo [Compile] cellular_noise...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) cellular_noise/cellular_noise.cr -o $(BIN_DIR)/cellular_noise$(EXE_EXT)

$(BIN_DIR)/surface_tool$(EXE_EXT): surface_tool/surface_tool.cr | $(BIN_DIR)
	@echo [Compile] surface_tool...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) surface_tool/surface_tool.cr -o $(BIN_DIR)/surface_tool$(EXE_EXT)

$(BIN_DIR)/astar_2d$(EXE_EXT): astar_2d/astar_2d.cr | $(BIN_DIR)
	@echo [Compile] astar_2d...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) astar_2d/astar_2d.cr -o $(BIN_DIR)/astar_2d$(EXE_EXT)

$(BIN_DIR)/tree_traversal$(EXE_EXT): tree_traversal/tree_traversal.cr | $(BIN_DIR)
	@echo [Compile] tree_traversal...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) tree_traversal/tree_traversal.cr -o $(BIN_DIR)/tree_traversal$(EXE_EXT)

$(BIN_DIR)/image_processing$(EXE_EXT): image_processing/image_processing.cr | $(BIN_DIR)
	@echo [Compile] image_processing...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) image_processing/image_processing.cr -o $(BIN_DIR)/image_processing$(EXE_EXT)

$(BIN_DIR)/transform_hierarchy$(EXE_EXT): transform_hierarchy/transform_hierarchy.cr | $(BIN_DIR)
	@echo [Compile] transform_hierarchy...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) transform_hierarchy/transform_hierarchy.cr -o $(BIN_DIR)/transform_hierarchy$(EXE_EXT)

$(BIN_DIR)/node_groups$(EXE_EXT): node_groups/node_groups.cr | $(BIN_DIR)
	@echo [Compile] node_groups...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) node_groups/node_groups.cr -o $(BIN_DIR)/node_groups$(EXE_EXT)

$(BIN_DIR)/vector_math_2d$(EXE_EXT): vector_math_2d/vector_math_2d.cr | $(BIN_DIR)
	@echo [Compile] vector_math_2d...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) vector_math_2d/vector_math_2d.cr -o $(BIN_DIR)/vector_math_2d$(EXE_EXT)

$(BIN_DIR)/dictionary_ops$(EXE_EXT): dictionary_ops/dictionary_ops.cr | $(BIN_DIR)
	@echo [Compile] dictionary_ops...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) dictionary_ops/dictionary_ops.cr -o $(BIN_DIR)/dictionary_ops$(EXE_EXT)

$(BIN_DIR)/config_file$(EXE_EXT): config_file/config_file.cr | $(BIN_DIR)
	@echo [Compile] config_file...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) config_file/config_file.cr -o $(BIN_DIR)/config_file$(EXE_EXT)

$(RUNNER): runner.cr $(wildcard src/*.cr) $(wildcard src/reporters/*.cr) | $(BIN_DIR)
	@echo [Compile] benchmark runner...
	@$(CRYSTAL) build $(CRYSTAL_FLAGS) runner.cr -o $(RUNNER)

run: build
	@$(RUNNER) -i $(or $(ITERATIONS),3)

chart: run
	@echo [Chart] Results available at results/

clean:
	@rm -rf $(BIN_DIR)/*.exe $(BIN_DIR)/*.pdb results/*.svg results/*.md results/*.html results/*.json results/*.csv
