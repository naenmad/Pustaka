.PHONY: all build-ffi build-ffi-release generate-project build-macos build-release install clean test

all: build-macos

# Compile Rust static library and generate UniFFI Swift bindings
build-ffi:
	@bash scripts/build-ffi.sh debug

build-ffi-release:
	@bash scripts/build-ffi.sh release

# Generate Xcode project using xcodegen
generate-project: build-ffi
	@cd macos && xcodegen generate

generate-project-release: build-ffi-release
	@cd macos && xcodegen generate

# Build macOS app in Debug mode
build-macos: generate-project
	@xcodebuild -project macos/Pustaka.xcodeproj -scheme Pustaka -configuration Debug -destination 'platform=macOS' build

# Build macOS app in optimized Release mode
build-release: generate-project-release
	@xcodebuild -project macos/Pustaka.xcodeproj -scheme Pustaka -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData build

# Install Pustaka.app to /Applications
install: build-release
	@echo "==> Installing Pustaka.app to /Applications..."
	@rm -rf /Applications/Pustaka.app
	@cp -R build/DerivedData/Build/Products/Release/Pustaka.app /Applications/
	@xattr -cr /Applications/Pustaka.app
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted /Applications/Pustaka.app
	@echo "==> Pustaka.app successfully installed to /Applications!"

# Run Rust cargo tests
test:
	@cargo test --workspace

# Clean build artifacts
clean:
	@cargo clean
	@rm -rf build/ macos/Pustaka/Generated macos/Pustaka.xcodeproj
