build/fundude.wasm: src/wasm/*
	@mkdir -p build
	emcc -o "$@" -Os src/wasm/*.c

.PHONY: build clean pkgbuild makepkg

build: build/fundude.wasm

clean:
	rm -rf build/*
