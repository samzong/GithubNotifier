.PHONY: clean build build-release install-app dmg lint lint-fix format format-check version help

# Variables
APP_NAME = GitHubNotifier
BUILD_DIR = .build
PROJECT_DIR := $(shell pwd)
HOST_ARCH := $(shell uname -m)

# Install variables
USER_APPLICATIONS = $(HOME)/Applications
DEBUG_APP = $(BUILD_DIR)/$(HOST_ARCH)-apple-macosx/debug/$(APP_NAME).app
RELEASE_APP = $(BUILD_DIR)/$(HOST_ARCH)-apple-macosx/release/$(APP_NAME).app
INSTALL_PATH = $(USER_APPLICATIONS)/$(APP_NAME).app

# Version information
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

ifndef VERSION
VERSION := $(shell git describe --tags --always 2>/dev/null || echo "0.1.0")
endif

ifndef MARKETING_SEMVER
MARKETING_SEMVER := $(shell \
    VERSION_STR="$(VERSION)"; \
    CLEAN=$$(echo $$VERSION_STR | sed -E 's/^v//; s/-.*//'); \
    if echo $$CLEAN | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$$'; then \
        echo $$CLEAN; \
    else \
        echo 0.1.0; \
    fi)
endif

ifndef BUILD_NUMBER
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo "1")
endif

# Architecture related variables
ARCHES := x86_64 arm64
DMG_VOLUME_NAME = "$(APP_NAME)"
DMG_LABEL_x86_64 = Intel
DMG_LABEL_arm64 = Apple Silicon

# Homebrew related variables
HOMEBREW_TAP_REPO = homebrew-tap
CASK_FILE = Casks/github-notifier.rb
BRANCH_NAME = update-github-notifier-$(MARKETING_SEMVER)

# ============================================================================
# Build Targets
# ============================================================================

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)

# Build for development (debug, current architecture)
build:
	@echo "🔨 Building $(APP_NAME) (debug)..."
	swift build
	./Scripts/package_app.sh debug
	@echo "✅ Build completed!"
	@echo "📍 Application: $(DEBUG_APP)"

# Build for release
build-release:
	@echo "🔨 Building $(APP_NAME) (release)..."
	swift build -c release
	./Scripts/package_app.sh release
	@echo "✅ Build completed!"
	@echo "📍 Application: $(RELEASE_APP)"

# Install app to ~/Applications and launch it
install-app: build-release
	@echo "⏹️  Stopping any running $(APP_NAME) instances..."
	@if pgrep -x "$(APP_NAME)" >/dev/null 2>&1; then \
		pkill -KILL -x "$(APP_NAME)" >/dev/null 2>&1; \
		echo "✅ $(APP_NAME) stopped."; \
	else \
		echo "ℹ️  $(APP_NAME) is not running."; \
	fi
	@echo "📦 Installing $(APP_NAME) to ~/Applications..."
	@mkdir -p "$(USER_APPLICATIONS)"
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "⚠️  Removing old version..."; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	@if [ -d "$(RELEASE_APP)" ]; then \
		cp -R "$(RELEASE_APP)" "$(USER_APPLICATIONS)/"; \
		echo "✅ $(APP_NAME) installed!"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(INSTALL_PATH)"; \
	else \
		echo "❌ Error: $(RELEASE_APP) not found"; \
		exit 1; \
	fi

# Quick run for development
run:
	./Scripts/compile_and_run.sh debug

# ============================================================================
# Code Quality
# ============================================================================

# Run swiftlint
lint:
	swiftlint Sources

# Run swiftlint with auto-fix
lint-fix:
	swiftlint --fix Sources

# Format code with SwiftFormat
format:
	swiftformat Sources --config .swiftformat

# Check formatting (for CI)
format-check:
	swiftformat Sources --config .swiftformat --lint

# Run all checks
check: format-check lint

# ============================================================================
# Version & Info
# ============================================================================

# Show version information
version:
	@echo "Version:      $(VERSION)"
	@echo "Git Commit:   $(GIT_COMMIT)"
	@echo "Marketing:    $(MARKETING_SEMVER)"
	@echo "Build Number: $(BUILD_NUMBER)"

# ============================================================================
# DMG Packaging (for release)
# ============================================================================

# Build release for specific architecture
define build_arch_release
	@echo "===> Building $(1) architecture..."
	swift build -c release --triple $(1)-apple-macosx
	./Scripts/package_app.sh release $(1)
endef

# Package DMG for specific architecture
define package_dmg
	@echo "===> Creating DMG for $(1)..."
	@rm -rf $(BUILD_DIR)/tmp-$(1)
	@mkdir -p $(BUILD_DIR)/tmp-$(1)
	@cp -r ".build/$(1)-apple-macosx/release/$(APP_NAME).app" "$(BUILD_DIR)/tmp-$(1)/"
	@ln -s /Applications "$(BUILD_DIR)/tmp-$(1)/Applications"
	hdiutil create -volname "$(DMG_VOLUME_NAME) ($(2))" \
		-srcfolder "$(BUILD_DIR)/tmp-$(1)" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(APP_NAME)-$(1).dmg"
	@rm -rf $(BUILD_DIR)/tmp-$(1)
	@echo "✅ Created $(BUILD_DIR)/$(APP_NAME)-$(1).dmg"
endef

# Build DMGs for both architectures
dmg:
	$(call build_arch_release,x86_64)
	$(call package_dmg,x86_64,$(DMG_LABEL_x86_64))
	swift package clean
	$(call build_arch_release,arm64)
	$(call package_dmg,arm64,$(DMG_LABEL_arm64))
	@echo ""
	@echo "===> All DMG files created:"
	@echo "    - x86_64 (Intel): $(BUILD_DIR)/$(APP_NAME)-x86_64.dmg"
	@echo "    - arm64 (Apple Silicon): $(BUILD_DIR)/$(APP_NAME)-arm64.dmg"
	@echo ""
	@echo "Note: These DMGs are self-signed; users may need to approve them."

# ============================================================================
# Homebrew
# ============================================================================

# Update Homebrew Cask
update-homebrew:
	@echo "===> Starting Homebrew cask update process..."
	@if [ -z "$(GH_PAT)" ]; then \
		echo "❌ Error: GH_PAT environment variable is required"; \
		exit 1; \
	fi
	@echo "===> Current version information:"
	@echo "    - VERSION: $(VERSION)"
	@echo "    - MARKETING_SEMVER: $(MARKETING_SEMVER)"
	@rm -rf tmp && mkdir -p tmp && \
	echo "===> Downloading DMG files..." && \
	curl -sfL -o tmp/$(APP_NAME)-x86_64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(MARKETING_SEMVER)/$(APP_NAME)-x86_64.dmg" && \
	curl -sfL -o tmp/$(APP_NAME)-arm64.dmg "https://github.com/samzong/$(APP_NAME)/releases/download/v$(MARKETING_SEMVER)/$(APP_NAME)-arm64.dmg" && \
	echo "===> Calculating SHA256 checksums..." && \
	X86_64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-x86_64.dmg | cut -d ' ' -f 1) && \
	ARM64_SHA256=$$(shasum -a 256 tmp/$(APP_NAME)-arm64.dmg | cut -d ' ' -f 1) && \
	echo "    - x86_64 SHA256: $$X86_64_SHA256" && \
	echo "    - arm64 SHA256: $$ARM64_SHA256" && \
	echo "===> Cloning Homebrew tap repository..." && \
	cd tmp && git clone https://$(GH_PAT)@github.com/samzong/$(HOMEBREW_TAP_REPO).git && \
	cd $(HOMEBREW_TAP_REPO) && \
	echo "    - Creating new branch: $(BRANCH_NAME)" && \
	git checkout -b $(BRANCH_NAME) && \
	echo "===> Updating cask file..." && \
	if [ -f $(CASK_FILE) ]; then \
		echo "    - Updating existing cask file with sed..."; \
		echo "    - Updating version to $(MARKETING_SEMVER)"; \
		sed -i '' 's/version "[^"]*"/version "$(MARKETING_SEMVER)"/' $(CASK_FILE); \
		if grep -q "on_arm" $(CASK_FILE); then \
			echo "    - Updating arm64 SHA256 to $$ARM64_SHA256"; \
			sed -i '' '/on_arm/,/end/{s/sha256 "[^"]*"/sha256 "'"$$ARM64_SHA256"'"/;}' $(CASK_FILE); \
			echo "    - Updating x86_64 SHA256 to $$X86_64_SHA256"; \
			sed -i '' '/on_intel/,/end/{s/sha256 "[^"]*"/sha256 "'"$$X86_64_SHA256"'"/;}' $(CASK_FILE); \
		else \
			echo "❌ Unknown cask format, cannot update SHA256 values"; \
			exit 1; \
		fi; \
	else \
		echo "❌ Error: Cask file not found. Please create it manually first."; \
		exit 1; \
	fi && \
	echo "===> Checking for changes..." && \
	if ! git diff --quiet $(CASK_FILE); then \
		echo "    - Changes detected, creating pull request..."; \
		git add $(CASK_FILE); \
		git config user.name "GitHub Actions"; \
		git config user.email "actions@github.com"; \
		git commit -m "chore: update $(APP_NAME) to v$(MARKETING_SEMVER)"; \
		git push -u origin $(BRANCH_NAME); \
		pr_data=$$(printf '{"title":"chore: update %s to v%s","body":"Auto-generated PR\\n- Version: %s\\n- x86_64 SHA256: %s\\n- arm64 SHA256: %s","head":"%s","base":"main"}' \
			"$(APP_NAME)" "$(MARKETING_SEMVER)" "$(MARKETING_SEMVER)" "$$X86_64_SHA256" "$$ARM64_SHA256" "$(BRANCH_NAME)"); \
		curl -X POST \
			-H "Authorization: token $(GH_PAT)" \
			-H "Content-Type: application/json" \
			https://api.github.com/repos/samzong/$(HOMEBREW_TAP_REPO)/pulls \
			-d "$$pr_data"; \
		echo "✅ Pull request created successfully"; \
	else \
		echo "❌ No changes detected in cask file"; \
		exit 1; \
	fi
	@echo "===> Cleaning up temporary files..."
	@rm -rf tmp
	@echo "✅ Homebrew cask update process completed"

# ============================================================================
# Help
# ============================================================================

help:
	@echo "$(APP_NAME) build targets (SPM-based):"
	@echo ""
	@echo "  Development:"
	@echo "    make build          Build debug version"
	@echo "    make run            Build, package, and launch (debug)"
	@echo "    make install-app    Build release and install to ~/Applications"
	@echo ""
	@echo "  Code Quality:"
	@echo "    make format         Format code with SwiftFormat"
	@echo "    make format-check   Check formatting (for CI)"
	@echo "    make lint           Run SwiftLint"
	@echo "    make lint-fix       Run SwiftLint with auto-fix"
	@echo "    make check          Run all checks"
	@echo ""
	@echo "  Release:"
	@echo "    make build-release  Build release version"
	@echo "    make dmg            Create DMGs for x86_64 and arm64"
	@echo "    make version        Print version info"
	@echo ""
	@echo "  Other:"
	@echo "    make clean          Remove build artifacts"
	@echo "    make update-homebrew GH_PAT=token  Update Homebrew cask"
	@echo ""
	@echo "Override MARKETING_SEMVER/BUILD_NUMBER when needed:"
	@echo "  MARKETING_SEMVER=1.0.0 make build-release"

.DEFAULT_GOAL := help
