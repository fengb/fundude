CC=clang
WASM_LD=wasm-ld

WASM_LIBC_DIR=vendor/wasi-sysroot
WASM_FLAGS=-Os --target=wasm32-freestanding -isystem $(WASM_LIBC_DIR)/include

SRC_DIR := src
OUT_DIR := build
SRC_FILES := $(wildcard $(SRC_DIR)/*.c)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%.o,$(SRC_FILES))

C_INCLUDE_PATH := src
export C_INCLUDE_PATH

TEST_MAIN_DIR := test
TEST_OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%-test.o,$(SRC_FILES))
TEST_MAIN_FILES := $(wildcard $(TEST_MAIN_DIR)/test_*.c)
TEST_TARGETS := $(patsubst $(TEST_MAIN_DIR)/%.c,%,$(TEST_MAIN_FILES))

$(OUT_DIR)/fundude.wasm: FILE_EXPORTS=$(shell scripts/c-functions src/main.h)
$(OUT_DIR)/fundude.wasm: LIB_EXPORTS=malloc free
$(OUT_DIR)/fundude.wasm: $(OBJ_FILES) $(WASM_LIBC_DIR)/lib/*.a
	$(WASM_LD) -o "$@" --no-entry $(patsubst %,--export=%,$(FILE_EXPORTS) $(LIB_EXPORTS)) $^

$(OUT_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	$(CC) -c -o $@ $(WASM_FLAGS) $<

$(OUT_DIR)/%-test.o: $(SRC_DIR)/%.c
	@mkdir -p $(OUT_DIR)
	$(CC) -c -o $@ $<

$(OUT_DIR)/test_%: $(TEST_OBJ_FILES) $(TEST_MAIN_DIR)/test_%.c
	@mkdir -p $(OUT_DIR)
	$(CC) -o "$@" $^

.PRECIOUS: $(OBJ_FILES) $(TEST_OBJ_FILES)

.PHONY: build test clean

build: build/fundude.wasm

test: $(TEST_TARGETS)

test_%: $(OUT_DIR)/test_%
	$<

clean:
	rm -rf build/*
