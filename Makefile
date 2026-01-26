# GitHubNotifier - Makefile

##@ Project Configuration
# ------------------------------------------------------------------------------
APP_NAME := GitHubNotifier
BUILD_DIR := .build
PROJECT_DIR := $(shell pwd)
HOST_ARCH := $(shell uname -m)

# Install variables
USER_APPLICATIONS := $(HOME)/Applications
INSTALL_PATH := $(USER_APPLICATIONS)/$(APP_NAME).app
RELEASE_APP := $(BUILD_DIR)/$(HOST_ARCH)-apple-macosx/release/$(APP_NAME).app

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
DMG_VOLUME_NAME := "$(APP_NAME)"
DMG_LABEL_x86_64 := Intel
DMG_LABEL_arm64 := Apple Silicon

# Homebrew related variables
HOMEBREW_TAP_REPO := homebrew-tap
CASK_FILE := Casks/github-notifier.rb
BRANCH_NAME := update-github-notifier-$(MARKETING_SEMVER)

# Terminal colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m

##@ General
# ------------------------------------------------------------------------------
.PHONY: help
help: ## Display available commands
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: version
version: ## Show version information
	@echo "Version:      $(VERSION)"
	@echo "Git Commit:   $(GIT_COMMIT)"
	@echo "Marketing:    $(MARKETING_SEMVER)"
	@echo "Build Number: $(BUILD_NUMBER)"

##@ Build AND RUN
# ------------------------------------------------------------------------------
# Macro for building and packaging
# Usage: $(call build_app,config,arch)
define build_app
	@echo "$(BLUE)🔨 Building $(APP_NAME) ($(1))...$(NC)"
	swift build -c $(1) $(if $(2),--triple $(2)-apple-macosx,)
	VERSION=$(VERSION) BUILD_NUMBER=$(BUILD_NUMBER) ./Scripts/package_app.sh $(1) $(2)
	@echo "$(GREEN)✅ Build completed!$(NC)"
endef

.PHONY: build
build: ## Build for development (debug, current architecture)
	$(call build_app,debug)
	@echo "$(BLUE)📍 Application: $(BUILD_DIR)/$(HOST_ARCH)-apple-macosx/debug/$(APP_NAME).app$(NC)"


.PHONY: run
run: ## Quick run for development
	@./Scripts/compile_and_run.sh debug


##@ Code Quality
# ------------------------------------------------------------------------------
.PHONY: lint
lint: ## Run swiftlint
	swiftlint Sources

.PHONY: lint-fix
lint-fix: ## Run swiftlint with auto-fix
	swiftlint --fix Sources

.PHONY: format
format: ## Format code with SwiftFormat
	swiftformat Sources --config .swiftformat

.PHONY: format-check
format-check: ## Check formatting (for CI)
	swiftformat Sources --config .swiftformat --lint

.PHONY: check
check: lint-fix lint format format-check  ## Run all checks

##@ Release
# ------------------------------------------------------------------------------
# Build release for specific architecture
define build_arch_release
	@echo "$(BLUE)===> Building $(1) architecture...$(NC)"
	$(call build_app,release,$(1))
endef

# Package DMG for specific architecture
define package_dmg
	@echo "$(BLUE)===> Creating DMG for $(1)...$(NC)"
	@rm -rf $(BUILD_DIR)/tmp-$(1)
	@mkdir -p $(BUILD_DIR)/tmp-$(1)
	@cp -r ".build/$(1)-apple-macosx/release/$(APP_NAME).app" "$(BUILD_DIR)/tmp-$(1)/"
	@ln -s /Applications "$(BUILD_DIR)/tmp-$(1)/Applications"
	hdiutil create -volname "$(DMG_VOLUME_NAME) ($(2))" \
		-srcfolder "$(BUILD_DIR)/tmp-$(1)" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(APP_NAME)-$(1).dmg"
	@rm -rf $(BUILD_DIR)/tmp-$(1)
	@echo "$(GREEN)✅ Created $(BUILD_DIR)/$(APP_NAME)-$(1).dmg$(NC)"
endef

.PHONY: dmg
dmg: ## Build DMGs for both architectures
	$(call build_arch_release,x86_64)
	$(call package_dmg,x86_64,$(DMG_LABEL_x86_64))
	$(call build_arch_release,arm64)
	$(call package_dmg,arm64,$(DMG_LABEL_arm64))
	@echo ""
	@echo "$(BLUE)===> All DMG files created:$(NC)"
	@echo "    - x86_64 (Intel): $(BUILD_DIR)/$(APP_NAME)-x86_64.dmg"
	@echo "    - arm64 (Apple Silicon): $(BUILD_DIR)/$(APP_NAME)-arm64.dmg"
	@echo ""
	@echo "Note: These DMGs are self-signed; users may need to approve them."

##@ Other
# ------------------------------------------------------------------------------
.PHONY: install
install: ## Build release and install to ~/Applications
	$(call build_app,release)
	@mkdir -p $(USER_APPLICATIONS)
	@rm -rf $(INSTALL_PATH)
	@cp -r $(RELEASE_APP) $(INSTALL_PATH)
	@echo "$(GREEN)✅ Installed to $(INSTALL_PATH)$(NC)"

.PHONY: clean
clean: ## Clean build artifacts
	swift package clean
	rm -rf $(BUILD_DIR)

.PHONY: update-homebrew
update-homebrew: ## Update Homebrew Cask (Requires GH_PAT)
	@GH_PAT=$(GH_PAT) \
	VERSION=$(VERSION) \
	MARKETING_SEMVER=$(MARKETING_SEMVER) \
	APP_NAME=$(APP_NAME) \
	HOMEBREW_TAP_REPO=$(HOMEBREW_TAP_REPO) \
	CASK_FILE=$(CASK_FILE) \
	BRANCH_NAME=$(BRANCH_NAME) \
	./Scripts/update_homebrew.sh

.DEFAULT_GOAL := help
