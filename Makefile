.PHONY: analyze test format smoke clean help

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

analyze: ## Run Flutter analyzer
	flutter analyze

test: ## Run all tests with coverage
	flutter test --coverage

format: ## Format Dart code
	dart format .

smoke: ## Run smoke test result generator
	dart run tool/smoke/smoke.dart

clean: ## Clean build artifacts
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/
