help:
	@just --list

build-with-config config:
	@mkdir -p build
	@cd build && cmake .. -DENABLE_UNIT_TESTS=OFF
	@cmake --build ./build --config {{config}} --target raylib-cpp-cmake-template -j 10 --

build-debug:
	@just build-with-config Debug

build-release:
	@just build-with-config Release

clean:
	@rm -rf build || true
	@rm -rf out || true

build-web:
	#!/usr/bin/env bash
	set -e

	# Activate Emscripten (adjust path as needed for your system)
	if [ -f "/usr/lib/emsdk/emsdk_env.sh" ]; then
		source "/usr/lib/emsdk/emsdk_env.sh"
	elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
		source "$HOME/emsdk/emsdk_env.sh"
	else
		echo "Warning: emsdk_env.sh not found, assuming emcc is in PATH"
	fi

	mkdir -p build-emc

	# Ensure asset folder is copied
	rm -rf build-emc/assets || true
	cp -R assets build-emc/assets

	cd build-emc
	emcmake cmake .. -DPLATFORM=Web -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="-s USE_GLFW=3" -DCMAKE_EXECUTABLE_SUFFIX=".html"
	emmake make -j$(nproc)

	echo "Build complete! Files are in build-emc/"

# Build web with gzip compression for deployment
# This matches the CI workflow for parity
build-web-dist:
	#!/usr/bin/env bash
	set -e
	just build-web

	echo "Creating distribution package..."
	mkdir -p dist/web

	# Rename HTML to index.html (matches CI rename_to_index target)
	cp build-emc/raylib-cpp-cmake-template.html dist/web/index.html

	# Inject gzip decompression snippet into index.html (matches CI inject_web_patch target)
	cmake -DHTML_PATH="dist/web/index.html" -DSNIPPET_PATH="cmake/inject_snippet.html" -P cmake/inject_snippet.cmake

	# Copy JS
	cp build-emc/*.js dist/web/

	# Gzip WASM and data files (matches CI gzip_assets target)
	for f in build-emc/*.wasm build-emc/*.data; do
		if [ -f "$f" ]; then
			gzip -9 -kf "$f"
			cp "${f}.gz" dist/web/
			echo "Compressed $(basename "$f")"
		fi
	done

	# Copy splash if it exists
	[ -f "assets/splash.png" ] && cp assets/splash.png dist/web/
	[ -f "assets/favicon.png" ] && cp assets/favicon.png dist/web/

	echo "Distribution ready in dist/web/"
	du -sh dist/web/

# Serve the web build locally for testing
serve-web:
	#!/usr/bin/env bash
	if [ -d "dist/web" ]; then
		cd dist/web && python3 -m http.server 8000
	elif [ -d "build-emc" ]; then
		cd build-emc && python3 -m http.server 8000
	else
		echo "No web build found. Run 'just build-web' first."
		exit 1
	fi

test:
	cmake -B build -DENABLE_UNIT_TESTS=ON
	cmake --build build --target unit_tests
	./build/tests/unit_tests --gtest_color=yes

test-asan:
	cmake -B build-asan -DENABLE_UNIT_TESTS=ON -DENABLE_ASAN=ON -DCMAKE_BUILD_TYPE=Debug
	cmake --build build-asan --target unit_tests
	./build-asan/tests/unit_tests --gtest_color=yes

ccache-stats:
	ccache -s

# Separate single-config build dirs to avoid CMake cache churn.
build-debug-fast:
	cmake -B build-debug -DCMAKE_BUILD_TYPE=Debug -DENABLE_UNIT_TESTS=OFF
	cmake --build build-debug --target raylib-cpp-cmake-template -j 10 --

build-release-fast:
	cmake -B build-release -DCMAKE_BUILD_TYPE=Release -DENABLE_UNIT_TESTS=OFF
	cmake --build build-release --target raylib-cpp-cmake-template -j 10 --

build-debug-ninja:
	cmake -B build-debug-ninja -G Ninja -DCMAKE_BUILD_TYPE=Debug
	cmake --build build-debug-ninja --target raylib-cpp-cmake-template -j --

build-release-ninja:
	cmake -B build-release-ninja -G Ninja -DCMAKE_BUILD_TYPE=Release
	cmake --build build-release-ninja --target raylib-cpp-cmake-template -j --

docs:
	doxygen Doxyfile

publish-web build_id="":
	@powershell -ExecutionPolicy Bypass -NoProfile -File scripts/publish_web.ps1 {{build_id}}
