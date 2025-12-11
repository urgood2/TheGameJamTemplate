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
	@rm -rf build-emc || true
	@rm -rf dist || true
	@rm -rf out || true
	@rm -f raylib-cpp-cmake-template_web.zip || true

# Clean only web-specific output files (matches CMake clean_web_build target)
clean-web:
	@rm -f build-emc/index.html || true
	@rm -f build-emc/raylib-cpp-cmake-template.html || true
	@rm -f build-emc/raylib-cpp-cmake-template.js || true
	@rm -f build-emc/raylib-cpp-cmake-template.wasm || true
	@rm -f build-emc/raylib-cpp-cmake-template.data || true
	@rm -f build-emc/*.gz || true

# Project configuration (matches CMakeLists.txt)
PROJECT_NAME := "raylib-cpp-cmake-template"
ITCH_USER := env_var_or_default("ITCH_USER", "chugget")
ITCH_PAGE := env_var_or_default("ITCH_PAGE", "testing")
WEB_BUILD_DIR := "build-emc"

# Emscripten linker flags (matches CMakeLists.txt _emscripten_link_flags)
EMSCRIPTEN_LINK_FLAGS := "-sUSE_GLFW=3 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -Oz -sALLOW_MEMORY_GROWTH=1 -gsource-map -sASSERTIONS=1 -sDISABLE_EXCEPTION_CATCHING=0 -sLEGACY_VM_SUPPORT=0 -DNDEBUG -s WASM=1 -s SIDE_MODULE=0 -s EXIT_RUNTIME=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 --closure 1"

build-web:
	#!/usr/bin/env bash
	set -e

	# Activate Emscripten (adjust path as needed for your system)
	if [ -n "${EMSDK:-}" ] && [ -f "${EMSDK}/emsdk_env.sh" ]; then
		source "${EMSDK}/emsdk_env.sh"
	elif [ -f "/usr/lib/emsdk/emsdk_env.sh" ]; then
		source "/usr/lib/emsdk/emsdk_env.sh"
	elif [ -f "$HOME/emsdk/emsdk_env.sh" ]; then
		source "$HOME/emsdk/emsdk_env.sh"
	else
		echo "Warning: emsdk_env.sh not found, assuming emcc is in PATH"
	fi

	mkdir -p {{WEB_BUILD_DIR}}

	# Ensure asset folder is copied (matches CMake copy_assets target)
	rm -rf {{WEB_BUILD_DIR}}/assets || true

	# Copy assets with filtering (matches CMake copy_assets logic)
	# Skip: .DS_Store, graphics/pre-packing-files_globbed, scripts_archived/,
	#       chugget_code_definitions.lua, siralim_data/, docs/
	find assets -type f \
		! -name '.DS_Store' \
		! -path '*graphics/pre-packing-files_globbed*' \
		! -path '*/scripts_archived/*' \
		! -name 'chugget_code_definitions.lua' \
		! -path '*/siralim_data/*' \
		! -path '*/docs/*' \
		| while read -r src; do
		dest="{{WEB_BUILD_DIR}}/$src"
		mkdir -p "$(dirname "$dest")"

		# Strip Lua comments for release-like builds (matches STRIP_LUA_COMMENTS_FOR_WEB)
		if [[ "$src" == *.lua ]] && command -v python3 >/dev/null 2>&1 && [ -f "scripts/strip_lua_comments.py" ]; then
			python3 scripts/strip_lua_comments.py "$src" "$dest"
		else
			cp "$src" "$dest"
		fi
	done

	cd {{WEB_BUILD_DIR}}

	# Configure with Emscripten (matches CMake _configure_args)
	# Uses RelWithDebInfo for debug symbols in source maps
	emcmake cmake .. \
		-DPLATFORM=Web \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_EXE_LINKER_FLAGS="{{EMSCRIPTEN_LINK_FLAGS}}" \
		-DCMAKE_EXECUTABLE_SUFFIX=.html \
		-DCCACHE_PROGRAM= \
		-DCMAKE_C_COMPILER_LAUNCHER= \
		-DCMAKE_CXX_COMPILER_LAUNCHER=

	cd build-emc
	emcmake cmake .. -DPLATFORM=Web -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="-s USE_GLFW=3" -DCMAKE_EXECUTABLE_SUFFIX=".html"
	emmake make -j$(nproc)

	echo "Build complete! Files are in {{WEB_BUILD_DIR}}/"

# Rename output HTML to index.html (matches CMake rename_to_index target)
rename-to-index:
	#!/usr/bin/env bash
	set -e
	echo "Checking for {{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.html..."
	if [ ! -f "{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.html" ]; then
		echo "ERROR: {{PROJECT_NAME}}.html not found. Build the project first."
		exit 1
	fi
	cp "{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.html" "{{WEB_BUILD_DIR}}/index.html"
	echo "Renamed to index.html"

# Inject snippet into <head> of index.html (matches CMake inject_web_patch target)
inject-web-patch:
	#!/usr/bin/env bash
	set -e
	echo "Checking for {{WEB_BUILD_DIR}}/index.html..."
	if [ ! -f "{{WEB_BUILD_DIR}}/index.html" ]; then
		echo "ERROR: index.html not found. Run 'just rename-to-index' first."
		exit 1
	fi
	echo "Injecting custom HTML snippet into <head>..."
	cmake -DHTML_PATH="{{WEB_BUILD_DIR}}/index.html" -DSNIPPET_PATH="cmake/inject_snippet.html" -P cmake/inject_snippet.cmake

# Gzip WASM and DATA files (matches CMake gzip_assets target)
gzip-assets:
	#!/usr/bin/env bash
	set -e
	WASM_FILE="{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.wasm"
	DATA_FILE="{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.data"

	echo "Checking for build outputs..."
	if [ ! -f "$WASM_FILE" ]; then
		echo "ERROR: $WASM_FILE not found. Build the project first."
		exit 1
	fi
	if [ ! -f "$DATA_FILE" ]; then
		echo "ERROR: $DATA_FILE not found. Build the project first."
		exit 1
	fi

	echo "Gzipping WASM and DATA files..."
	cp "$WASM_FILE" "${WASM_FILE}.orig"
	cp "$DATA_FILE" "${DATA_FILE}.orig"
	gzip -kf "$WASM_FILE"
	gzip -kf "$DATA_FILE"
	echo "Compressed .wasm and .data files"

# Build web with gzip compression for deployment
# This matches the CI workflow for parity
build-web-dist:
	#!/usr/bin/env bash
	set -e
	just build-web

	echo "Creating distribution package..."
	mkdir -p dist/web

	# Rename HTML to index.html (matches CI rename_to_index target)
	cp {{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.html dist/web/index.html

	# Inject gzip decompression snippet into index.html (matches CI inject_web_patch target)
	cmake -DHTML_PATH="dist/web/index.html" -DSNIPPET_PATH="cmake/inject_snippet.html" -P cmake/inject_snippet.cmake

	# Copy JS
	cp {{WEB_BUILD_DIR}}/*.js dist/web/

	# Gzip WASM and data files (matches CI gzip_assets target)
	for f in {{WEB_BUILD_DIR}}/*.wasm {{WEB_BUILD_DIR}}/*.data; do
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

# Post-process web build: rename, inject patch, gzip, and create zip
# (matches CMake workflow: rename_to_index -> inject_web_patch -> gzip_assets -> zip)
web-postprocess:
	#!/usr/bin/env bash
	set -e

	html="{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.html"
	out="{{WEB_BUILD_DIR}}/index.html"

	if [ ! -f "$html" ]; then
		echo "Missing $html. Run 'just build-web' first."
		exit 1
	fi

	# rename_to_index
	cp "$html" "$out"

	# inject_web_patch
	cmake -DHTML_PATH="$out" -DSNIPPET_PATH="cmake/inject_snippet.html" -P cmake/inject_snippet.cmake

	# gzip_assets
	gzip -9 -kf "{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.wasm"
	gzip -9 -kf "{{WEB_BUILD_DIR}}/{{PROJECT_NAME}}.data"

	# zip_web_build (matches CMake zip_web_build target)
	(
		cd {{WEB_BUILD_DIR}}
		cmake -E tar "cf" ../{{PROJECT_NAME}}_web.zip --format=zip \
			index.html \
			{{PROJECT_NAME}}.wasm.gz \
			{{PROJECT_NAME}}.data.gz \
			{{PROJECT_NAME}}.js \
			assets
	)
	echo "Created {{PROJECT_NAME}}_web.zip"

# Push web build to itch.io (matches CMake push_web_build target)
push-web:
	#!/usr/bin/env bash
	set -e

	: "${WEB_JOBS:=2}"

	just clean-web
	just build-web
	just web-postprocess

	itch_user="{{ITCH_USER}}"
	itch_page="{{ITCH_PAGE}}"

	# Version handling matches CMakeLists.txt CRASH_REPORT_BUILD_ID logic:
	# 1. ITCH_BUILD_ID env var
	# 2. TELEMETRY_BUILD_ID env var
	# 3. BUILD_ID env var
	# 4. git describe --tags --always --dirty
	# 5. fallback to "dev"
	version="${ITCH_BUILD_ID:-}"
	if [ -z "$version" ]; then version="${TELEMETRY_BUILD_ID:-}"; fi
	if [ -z "$version" ]; then version="${BUILD_ID:-}"; fi
	if [ -z "$version" ]; then version="${CRASH_REPORT_BUILD_ID:-}"; fi
	if [ -z "$version" ]; then version="$(git describe --tags --always --dirty 2>/dev/null || echo dev)"; fi

	if ! command -v butler >/dev/null 2>&1; then
		echo "butler is not on PATH. Install and login first."
		exit 1
	fi

	echo "Pushing to ${itch_user}/${itch_page}:web with version ${version}"
	butler push {{PROJECT_NAME}}_web.zip "${itch_user}/${itch_page}:web" --userversion "${version}"

# Serve the web build locally for testing
serve-web:
	#!/usr/bin/env bash
	if [ -d "dist/web" ]; then
		cd dist/web && python3 -m http.server 8000
	elif [ -d "{{WEB_BUILD_DIR}}" ]; then
		cd {{WEB_BUILD_DIR}} && python3 -m http.server 8000
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
