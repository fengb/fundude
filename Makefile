build/fundude.js: src/wasm/*
	@mkdir -p build
	emcc -o "$@" -s SINGLE_FILE=1 -s MODULARIZE=1 -s EXPORT_ES6=1 -s "EXTRA_EXPORTED_RUNTIME_METHODS=['ccall']" src/wasm/*.c

.PHONY: build clean pkgbuild makepkg

build: build/fundude.js

clean:
	rm -rf build/*
