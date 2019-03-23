build/fundude.wasm: src/wasm/*
	@mkdir -p build
	emcc -o "$@" -s SINGLE_FILE=1 -s MODULARIZE=1 -s EXPORT_ES6=1 src/wasm/*.c

.PHONY: build clean pkgbuild makepkg

build: build/fundude.wasm

clean:
	rm -rf build/*
