CC=clang
SRC_DIR := src/wasm
OUT_DIR := build
SRC_FILES := $(wildcard $(SRC_DIR)/[!_]*.c)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%.o,$(SRC_FILES))

TEST_MAIN_DIR := test/wasm
TEST_MAIN_FILES := $(wildcard $(TEST_MAIN_DIR)/test_*.c)
TEST_OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%.test.o,$(SRC_FILES))
TEST_TARGETS := $(patsubst $(TEST_MAIN_DIR)/%.c,%,$(TEST_MAIN_FILES))

$(OUT_DIR)/fundude.js: LINK_FLAGS = -s SINGLE_FILE=1 -s MODULARIZE=1 -s EXPORT_ES6=1 -s "EXTRA_EXPORTED_RUNTIME_METHODS=['ccall']"
$(OUT_DIR)/fundude.js: $(OBJ_FILES)
	emcc -o "$@" $(LINK_FLAGS) $^ $(SRC_DIR)/_emscripten.c

$(OUT_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	emcc -c -o $@ $<

$(OUT_DIR)/test_%: $(TEST_OBJ_FILES) $(TEST_MAIN_DIR)/test_%.c
	@mkdir -p $(OUT_DIR)
	$(CC) -I$(SRC_DIR) -o "$@" $^

$(OUT_DIR)/%.test.o: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	$(CC) -c -o "$@" $^

.PHONY: build test clean

build: build/fundude.js

test: $(TEST_TARGETS)

test_%: $(OUT_DIR)/test_%
	$<

clean:
	rm -rf build/*
