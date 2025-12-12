# =============================================================================
# TheGameJamTemplate Build System
# =============================================================================
# NOTE: Web build recipes (build-web, deploy-web, etc.) support macOS and Linux only.
# For Windows web builds, use CMake targets directly:
#   cmake --build build-emc --target push_web_build
# =============================================================================

# =============================================================================
# Project Configuration
# =============================================================================
project_name := "raylib-cpp-cmake-template"

# Itch.io settings (match CMakeLists.txt lines 250-251)
itch_user := "chugget"
itch_page := "testing"

# Web build directory (match CMakeLists.txt WEB_BUILD_DIR)
web_build_dir := "build-emc"

# Output zip file
web_zip := project_name + "_web.zip"

# =============================================================================
# Help
# =============================================================================
help:
	@just --list

# =============================================================================
# Native Builds
# =============================================================================
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

# =============================================================================
# Testing
# =============================================================================
test:
	cmake -B build -DENABLE_UNIT_TESTS=ON
	cmake --build build --target unit_tests
	./build/tests/unit_tests --gtest_color=yes

test-asan:
	cmake -B build-asan -DENABLE_UNIT_TESTS=ON -DENABLE_ASAN=ON -DCMAKE_BUILD_TYPE=Debug
	cmake --build build-asan --target unit_tests
	./build-asan/tests/unit_tests --gtest_color=yes

# =============================================================================
# Utilities
# =============================================================================
ccache-stats:
	ccache -s

docs:
	doxygen Doxyfile

# =============================================================================
# Web Build - Individual Steps (match CMakeLists.txt targets)
# =============================================================================

# Get version string from git (match CMakeLists.txt lines 263-280)
@_get-version:
	#!/usr/bin/env bash
	version=$(git describe --tags --always --dirty 2>/dev/null)
	if [ -z "$version" ]; then
		version="0.1"
	fi
	echo "$version"

# Detect butler executable path (match CMakeLists.txt BUTLER_PATH logic)
# Checks: BUTLER_PATH env → itch.io app install → PATH
@_get-butler-path:
	#!/usr/bin/env bash
	# 1. Check BUTLER_PATH env var
	if [ -n "$BUTLER_PATH" ]; then
		if [ -d "$BUTLER_PATH" ]; then
			echo "$BUTLER_PATH/butler"
		else
			echo "$BUTLER_PATH"
		fi
		exit 0
	fi

	# 2. Check itch.io app installation (macOS)
	itch_butler="$HOME/Library/Application Support/itch/broth/butler"
	if [ -d "$itch_butler/versions" ]; then
		# Find latest version
		latest=$(ls -1 "$itch_butler/versions" 2>/dev/null | sort -V | tail -1)
		if [ -n "$latest" ] && [ -x "$itch_butler/versions/$latest/butler" ]; then
			echo "$itch_butler/versions/$latest/butler"
			exit 0
		fi
	fi

	# 3. Check alternate itch.io app location
	alt_butler="$HOME/Library/Application Support/itch/apps/butler/butler"
	if [ -x "$alt_butler" ]; then
		echo "$alt_butler"
		exit 0
	fi

	# 4. Check Linux itch.io location
	linux_butler="$HOME/.config/itch/broth/butler"
	if [ -d "$linux_butler/versions" ]; then
		latest=$(ls -1 "$linux_butler/versions" 2>/dev/null | sort -V | tail -1)
		if [ -n "$latest" ] && [ -x "$linux_butler/versions/$latest/butler" ]; then
			echo "$linux_butler/versions/$latest/butler"
			exit 0
		fi
	fi

	# 5. Fall back to PATH
	if command -v butler &>/dev/null; then
		echo "butler"
		exit 0
	fi

	echo "ERROR: butler not found. Install via itch.io app or set BUTLER_PATH env var" >&2
	exit 1

# Detect EMSDK path (match CMakeLists.txt lines 916-924)
@_get-emsdk-path:
	#!/usr/bin/env bash
	if [ -n "$EMSDK" ]; then
		echo "$EMSDK"
	elif [ -d "$HOME/emsdk" ]; then
		echo "$HOME/emsdk"
	elif [ -d "/usr/lib/emsdk" ]; then
		echo "/usr/lib/emsdk"
	else
		echo "ERROR: EMSDK not found. Set EMSDK env var or install to ~/emsdk" >&2
		exit 1
	fi

# Step 1: Copy assets with exclusions and optional Lua stripping
# Match CMakeLists.txt copy_assets target (lines 899-908)
copy-web-assets strip_lua="true":
	#!/usr/bin/env bash
	set -e
	echo "=== Copying assets to {{web_build_dir}}/assets ==="

	strip_flag=""
	if [ "{{strip_lua}}" = "true" ]; then
		strip_flag="--strip-lua"
		echo "  Lua comment stripping: ENABLED"
	fi

	python3 scripts/copy_assets.py \
		assets \
		{{web_build_dir}}/assets \
		$strip_flag

	echo "=== Assets copied ==="

# Step 2: Configure and build web (match CMakeLists.txt configure_web_build + compile_web_build)
build-web: copy-web-assets
	#!/usr/bin/env bash
	set -e

	# Get EMSDK path
	EMSDK_PATH=$(just _get-emsdk-path)
	echo "=== Using EMSDK at: $EMSDK_PATH ==="

	# Source emsdk environment and activate latest (match CMakeLists.txt activate_emsdk target)
	source "$EMSDK_PATH/emsdk_env.sh"
	echo "=== Activating emsdk latest ==="
	emsdk activate latest --permanent

	mkdir -p {{web_build_dir}}
	cd {{web_build_dir}}

	# Linker flags matching CMakeLists.txt line 962
	# NOTE: --closure 1 removed because miniaudio/telemetry JS isn't closure-compatible
	# NOTE: -sDISABLE_EXCEPTION_CATCHING=0 enables C++ exceptions (needed for nlohmann::json)
	# NOTE: EXPORTED_RUNTIME_METHODS needed for audio (HEAPF32) and telemetry (stringToUTF8OnStack)
	LINK_FLAGS="-sUSE_GLFW=3 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -Oz -sALLOW_MEMORY_GROWTH=1 -gsource-map -sASSERTIONS=1 -sDISABLE_EXCEPTION_CATCHING=0 -DNDEBUG -s WASM=1 -s SIDE_MODULE=0 -s EXIT_RUNTIME=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPF64,HEAP8,HEAP16,HEAP32,HEAPU8,HEAPU16,HEAPU32,stringToUTF8OnStack,UTF8ToString,stringToUTF8,lengthBytesUTF8"

	echo "=== Configuring CMake with Emscripten ==="
	# Match CMakeLists.txt line 963 configure args
	emcmake cmake .. \
		-DPLATFORM=Web \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_EXE_LINKER_FLAGS="$LINK_FLAGS" \
		-DCMAKE_EXECUTABLE_SUFFIX=.html \
		-DCCACHE_PROGRAM= \
		-DCMAKE_C_COMPILER_LAUNCHER= \
		-DCMAKE_CXX_COMPILER_LAUNCHER=

	echo "=== Building web target ==="
	cmake --build .

	echo "=== Web build complete ==="

# Step 3: Rename output to index.html (match CMakeLists.txt rename_to_index target)
rename-to-index:
	#!/usr/bin/env bash
	set -e
	echo "=== Renaming {{project_name}}.html to index.html ==="
	cp {{web_build_dir}}/{{project_name}}.html {{web_build_dir}}/index.html
	echo "=== Rename complete ==="

# Step 4: Inject pako gzip decompression snippet (match CMakeLists.txt inject_web_patch target)
inject-web-snippet:
	#!/usr/bin/env bash
	set -e
	echo "=== Injecting custom HTML snippet into <head> ==="

	# Use CMake script for cross-platform compatibility (match CMakeLists.txt line 957)
	cmake \
		-DHTML_PATH="{{web_build_dir}}/index.html" \
		-DSNIPPET_PATH="cmake/inject_snippet.html" \
		-P cmake/inject_snippet.cmake

	echo "=== Snippet injected ==="

# Step 5: Gzip wasm and data files (match CMakeLists.txt gzip_assets target)
gzip-web-assets:
	#!/usr/bin/env bash
	set -e
	echo "=== Gzipping WASM and DATA files ==="

	WASM_FILE="{{web_build_dir}}/{{project_name}}.wasm"
	DATA_FILE="{{web_build_dir}}/{{project_name}}.data"

	# Keep originals as backup (match CMakeLists.txt lines 1027-1028)
	cp "$WASM_FILE" "$WASM_FILE.orig"
	cp "$DATA_FILE" "$DATA_FILE.orig"

	# Gzip with -k (keep original) and -f (force)
	gzip -kf "$WASM_FILE"
	gzip -kf "$DATA_FILE"

	# Show size reduction
	orig_wasm=$(stat -f%z "$WASM_FILE.orig" 2>/dev/null || stat -c%s "$WASM_FILE.orig")
	gz_wasm=$(stat -f%z "$WASM_FILE.gz" 2>/dev/null || stat -c%s "$WASM_FILE.gz")
	orig_data=$(stat -f%z "$DATA_FILE.orig" 2>/dev/null || stat -c%s "$DATA_FILE.orig")
	gz_data=$(stat -f%z "$DATA_FILE.gz" 2>/dev/null || stat -c%s "$DATA_FILE.gz")

	echo "  WASM: $orig_wasm → $gz_wasm bytes"
	echo "  DATA: $orig_data → $gz_data bytes"
	echo "=== Gzip complete ==="

# Step 6: Create distribution zip (match CMakeLists.txt zip_web_build target)
zip-web-build:
	#!/usr/bin/env bash
	set -e
	echo "=== Creating distribution zip: {{web_zip}} ==="

	cd {{web_build_dir}}

	# Match CMakeLists.txt line 1038 - zip with gzipped files
	# Note: Using zip instead of tar for better compatibility
	rm -f ../{{web_zip}}
	zip -r ../{{web_zip}} \
		index.html \
		{{project_name}}.wasm.gz \
		{{project_name}}.data.gz \
		{{project_name}}.js \
		assets

	cd ..
	echo "=== Zip created: {{web_zip}} ($(du -h {{web_zip}} | cut -f1)) ==="

# Step 7: Push to itch.io (match CMakeLists.txt push_web_build target)
push-itch-web channel="web":
	#!/usr/bin/env bash
	set -e

	version=$(just _get-version)
	butler_exe=$(just _get-butler-path)

	echo "=== Pushing to itch.io ==="
	echo "  Butler: $butler_exe"
	echo "  Project: {{itch_user}}/{{itch_page}}"
	echo "  Channel: {{channel}}"
	echo "  Version: $version"

	"$butler_exe" push {{web_zip}} {{itch_user}}/{{itch_page}}:{{channel}} --userversion "$version"

	echo "=== Push complete ==="

# =============================================================================
# Web Build - Combined Pipelines
# =============================================================================

# Clean only web-specific output files (match CMakeLists.txt clean_web_build target)
clean-web:
	#!/usr/bin/env bash
	echo "=== Cleaning web-specific output files ==="
	rm -f {{web_build_dir}}/index.html
	rm -f {{web_build_dir}}/{{project_name}}.html
	rm -f {{web_build_dir}}/{{project_name}}.js
	rm -f {{web_build_dir}}/{{project_name}}.wasm
	rm -f {{web_build_dir}}/{{project_name}}.wasm.gz
	rm -f {{web_build_dir}}/{{project_name}}.wasm.orig
	rm -f {{web_build_dir}}/{{project_name}}.data
	rm -f {{web_build_dir}}/{{project_name}}.data.gz
	rm -f {{web_build_dir}}/{{project_name}}.data.orig
	rm -f {{web_zip}}
	echo "=== Clean complete ==="

# Full web build pipeline (build only, no push)
build-web-full: build-web rename-to-index inject-web-snippet gzip-web-assets zip-web-build
	@echo "=== Full web build pipeline complete ==="
	@echo "  Output: {{web_zip}}"

# Full deploy pipeline: clean → build → push (match CMakeLists.txt push_web_build dependencies)
deploy-web channel="web": clean-web build-web-full (push-itch-web channel)
	@echo "=== Deploy complete ==="

# Deploy to dev channel (convenience alias)
deploy-web-dev:
	just deploy-web web-dev

# =============================================================================
# Web Build - Debug/Development Helpers
# =============================================================================

# Quick web build without gzip (for local testing)
build-web-quick: copy-web-assets
	#!/usr/bin/env bash
	set -e

	EMSDK_PATH=$(just _get-emsdk-path)
	source "$EMSDK_PATH/emsdk_env.sh"
	emsdk activate latest --permanent

	mkdir -p {{web_build_dir}}
	cd {{web_build_dir}}

	# Simpler flags for faster iteration
	emcmake cmake .. \
		-DPLATFORM=Web \
		-DCMAKE_BUILD_TYPE=Debug \
		-DCMAKE_EXE_LINKER_FLAGS="-sUSE_GLFW=3 -sALLOW_MEMORY_GROWTH=1 -sASSERTIONS=2" \
		-DCMAKE_EXECUTABLE_SUFFIX=.html

	cmake --build .
	cp {{project_name}}.html index.html

	echo "=== Quick web build complete (no gzip) ==="
	echo "  Serve with: python3 -m http.server -d {{web_build_dir}} 8080"

# Serve web build locally for testing
serve-web port="8080":
	#!/usr/bin/env bash
	echo "=== Serving {{web_build_dir}} on http://localhost:{{port}} ==="
	echo "  Press Ctrl+C to stop"
	python3 -m http.server -d {{web_build_dir}} {{port}}

# Show web build sizes
web-sizes:
	#!/usr/bin/env bash
	echo "=== Web Build File Sizes ==="
	if [ -d "{{web_build_dir}}" ]; then
		echo "Build directory: {{web_build_dir}}"
		ls -lh {{web_build_dir}}/{{project_name}}.* 2>/dev/null || echo "  No build files found"
		ls -lh {{web_build_dir}}/index.html 2>/dev/null || true
		echo ""
		if [ -d "{{web_build_dir}}/assets" ]; then
			echo "Assets directory size:"
			du -sh {{web_build_dir}}/assets
		fi
	else
		echo "  Build directory not found: {{web_build_dir}}"
	fi
	echo ""
	if [ -f "{{web_zip}}" ]; then
		echo "Distribution zip: {{web_zip}}"
		ls -lh {{web_zip}}
	else
		echo "  No distribution zip found"
	fi
