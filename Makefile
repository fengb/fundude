CC=clang
SRC_DIR := src
OUT_DIR := build
SRC_FILES := $(wildcard $(SRC_DIR)/*.c)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%.bc,$(SRC_FILES))

C_INCLUDE_PATH := src
export C_INCLUDE_PATH

TEST_MAIN_DIR := test
TEST_MAIN_FILES := $(wildcard $(TEST_MAIN_DIR)/test_*.c)
TEST_TARGETS := $(patsubst $(TEST_MAIN_DIR)/%.c,%,$(TEST_MAIN_FILES))

$(OUT_DIR)/fundude.js: LINK_FLAGS = -s SINGLE_FILE=1 -s MODULARIZE=1 -s EXPORT_ES6=1 -s "EXTRA_EXPORTED_RUNTIME_METHODS=['ccall']"
$(OUT_DIR)/fundude.js: $(OBJ_FILES)
	emcc -o "$@" $(LINK_FLAGS) $^ $(SRC_DIR)/wasm/main.c

$(OUT_DIR)/%.bc: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	emcc -c -o $@ $<

$(OUT_DIR)/test_%: $(OBJ_FILES) $(TEST_MAIN_DIR)/test_%.c
	@mkdir -p $(OUT_DIR)
	$(CC) -Wno-override-module -o "$@" $^

.PHONY: build test clean

build: build/fundude.js

test: $(TEST_TARGETS)

test_%: $(OUT_DIR)/test_%
	$<

clean:
	rm -rf build/*
