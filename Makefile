.PHONY: clean build install-app dmg help

# Variables
APP_NAME = GitHubNotifier
BUILD_DIR = build

# Install variables
CONFIGURATION = Release
BUILT_APP_PATH = $(BUILD_DIR)/$(CONFIGURATION)/$(APP_NAME).app
USER_APPLICATIONS = $(HOME)/Applications
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

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -scheme $(APP_NAME) 2>/dev/null || true

# Build for local development (current architecture)
build:
	@echo "🔨 Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-scheme $(APP_NAME) \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS' \
		build \
		SYMROOT=$(BUILD_DIR) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) \
		MARKETING_VERSION=$(MARKETING_SEMVER)
	@echo "✅ Build completed!"
	@echo "📍 Application: $(BUILT_APP_PATH)"

# Install app to ~/Applications and launch it
install-app:
	@echo "⏹️  Stopping any running $(APP_NAME) instances..."
	@if pgrep -x "$(APP_NAME)" >/dev/null 2>&1; then \
		pkill -KILL -x "$(APP_NAME)" >/dev/null 2>&1; \
		echo "✅ $(APP_NAME) stopped."; \
	else \
		echo "ℹ️  $(APP_NAME) is not running."; \
	fi
	@$(MAKE) --no-print-directory build
	@echo "📦 Installing $(APP_NAME) to ~/Applications..."
	@mkdir -p "$(USER_APPLICATIONS)"
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "⚠️  Removing old version..."; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	@if [ -d "$(BUILT_APP_PATH)" ]; then \
		cp -R "$(BUILT_APP_PATH)" "$(USER_APPLICATIONS)/"; \
		echo "✅ $(APP_NAME) installed!"; \
		echo "🚀 Launching $(APP_NAME)..."; \
		open "$(INSTALL_PATH)"; \
	else \
		echo "❌ Error: $(BUILT_APP_PATH) not found"; \
		exit 1; \
	fi

# Run swiftlint
lint:
	swiftlint

# Run swiftlint with auto-fix
lint-fix:
	swiftlint --fix

# Show version information
version:
	@echo "Version:      $(VERSION)"
	@echo "Git Commit:   $(GIT_COMMIT)"
	@echo "Marketing:    $(MARKETING_SEMVER)"
	@echo "Build Number: $(BUILD_NUMBER)"

# Help command
help:
	@echo "$(APP_NAME) build targets:"
	@echo "  make build        Build app for the current architecture"
	@echo "  make install-app  Build, install to ~/Applications, and launch"
	@echo "  make lint         Run swiftlint"
	@echo "  make lint-fix     Run swiftlint with auto-fix"
	@echo "  make version      Print version info"
	@echo "  make clean        Remove build artifacts"

.DEFAULT_GOAL := help
