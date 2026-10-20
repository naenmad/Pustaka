.PHONY: all build-ffi build-ffi-release generate-project build-macos clean test

all: build-macos

# Compile Rust static library and generate UniFFI Swift bindings
build-ffi:
	@bash scripts/build-ffi.sh debug

build-ffi-release:
	@bash scripts/build-ffi.sh release

# Generate Xcode project using xcodegen
generate-project: build-ffi
	@cd macos && xcodegen generate

# Build macOS app using xcodebuild
build-macos: generate-project
	@xcodebuild -project macos/Pustaka.xcodeproj -scheme Pustaka -configuration Debug -destination 'platform=macOS' build

# Run Rust cargo tests
test:
	@cargo test --workspace

# Clean build artifacts
clean:
	@cargo clean
	@rm -rf macos/Pustaka/Generated macos/Pustaka.xcodeproj
