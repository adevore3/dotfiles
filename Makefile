# Makefile for dotfiles management
# https://github.com/adevore3/dotfiles

.PHONY: help test install lint lint-functions lint-scripts update-submodules clean env-setup

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@DOTFILES=${PWD} bash ./run_all_tests.sh

install: ## Install dotfiles (creates symlinks)
	@echo "$(BLUE)Installing dotfiles...$(NC)"
	@./install

env-setup: ## Run environment setup (installs dependencies)
	@echo "$(BLUE)Running environment setup...$(NC)"
	@sudo ./env-setup.sh

lint: lint-functions lint-scripts ## Run shellcheck on all shell files

lint-functions: ## Lint bash functions
	@echo "$(BLUE)Linting bash functions...$(NC)"
	@find bash/functions -type f -name "*.func" 2>/dev/null | xargs shellcheck || true

lint-scripts: ## Lint shell scripts
	@echo "$(BLUE)Linting shell scripts...$(NC)"
	@find . -type f -name "*.sh" ! -path "./autojump/*" ! -path "./dotbot/*" ! -path "./indeed/*" 2>/dev/null | xargs shellcheck || true

lint-verbose: ## Run shellcheck with verbose output
	@echo "$(BLUE)Running verbose shellcheck...$(NC)"
	@find bash/functions -type f -name "*.func" 2>/dev/null | xargs shellcheck -f gcc
	@find . -type f -name "*.sh" ! -path "./autojump/*" ! -path "./dotbot/*" ! -path "./indeed/*" 2>/dev/null | xargs shellcheck -f gcc

update-submodules: ## Update git submodules
	@echo "$(BLUE)Updating submodules...$(NC)"
	@git submodule update --init --recursive

update-submodules-remote: ## Update submodules to latest remote commits
	@echo "$(BLUE)Updating submodules to latest remote...$(NC)"
	@git submodule update --remote --merge

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@find . -type f -name "*.out" -path "/tmp/*" -delete 2>/dev/null || true
	@echo "$(GREEN)Clean complete$(NC)"

list-functions: ## List all available bash functions with descriptions
	@echo "$(BLUE)Available functions by category:$(NC)"
	@for category in bash/functions/*/; do \
		if [ -d "$$category" ] && [ "$$(basename $$category)" != "test" ]; then \
			echo "\n$(GREEN)$$(basename $$category):$(NC)"; \
			find "$$category" -maxdepth 1 -name "*.func" -exec basename {} .func \; | sort | sed 's/^/  - /'; \
		fi \
	done

check-shellcheck: ## Check if shellcheck is installed
	@which shellcheck > /dev/null || (echo "$(RED)shellcheck not found. Install with: apt install shellcheck$(NC)" && exit 1)
	@echo "$(GREEN)shellcheck is installed$(NC)"

stats: ## Show repository statistics
	@echo "$(BLUE)Repository Statistics:$(NC)"
	@echo "$(GREEN)Functions:$(NC) $$(find bash/functions -name "*.func" | wc -l)"
	@echo "$(GREEN)Tests:$(NC) $$(find . -name "*_test.sh" | wc -l)"
	@echo "$(GREEN)Scripts:$(NC) $$(find . -name "*.sh" ! -path "./autojump/*" ! -path "./dotbot/*" ! -path "./indeed/*" | wc -l)"
	@echo "$(GREEN)Total lines of shell code:$(NC) $$(find . \( -name "*.sh" -o -name "*.func" -o -name "*.bash" \) ! -path "./autojump/*" ! -path "./dotbot/*" ! -path "./indeed/*" -exec cat {} \; | wc -l)"
