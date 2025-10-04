.PHONY: analyze test format smoke clean help build-web size-report audit functions-test rules-test validate-stabilization validate-updates

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

build-web: ## Build Flutter web app
	flutter build web --release

build-web-budget: ## Build web and check bundle size budget
	flutter build web --release
	@TOTAL_SIZE=$$(du -sb build/web | cut -f1); \
	MAX_SIZE=10485760; \
	echo "Web build size: $$TOTAL_SIZE bytes"; \
	if [ $$TOTAL_SIZE -gt $$MAX_SIZE ]; then \
		echo "ERROR: Web build size exceeds budget ($$MAX_SIZE bytes)"; \
		exit 1; \
	fi; \
	echo "✅ Web build within budget"

size-report: ## Generate build size report
	@echo "Generating build size report..."
	@if [ -f build/app/outputs/flutter-apk/app-debug.apk ]; then \
		APK_SIZE=$$(stat -c%s build/app/outputs/flutter-apk/app-debug.apk 2>/dev/null || stat -f%z build/app/outputs/flutter-apk/app-debug.apk); \
		echo "Android APK: $$APK_SIZE bytes"; \
	fi
	@if [ -d build/web ]; then \
		WEB_SIZE=$$(du -sb build/web | cut -f1); \
		echo "Web bundle: $$WEB_SIZE bytes"; \
	fi

audit: ## Run dependency audit
	@echo "Auditing Flutter packages..."
	flutter pub outdated
	@echo ""
	@echo "Auditing Functions dependencies..."
	cd functions && npm audit
	@echo ""
	@echo "Auditing WebApp dependencies..."
	cd webapp && npm audit

functions-test: ## Run Functions tests with emulators
	@echo "Starting Firebase emulators and running Functions tests..."
	cd functions && npm test

rules-test: ## Run Firestore rules tests
	@echo "Running Firestore rules tests..."
	cd firestore-tests && npm test

validate-stabilization: ## Validate compliance with stabilization standards
	@echo "Running stabilization compliance check..."
	@chmod +x scripts/validate_stabilization.sh
	@./scripts/validate_stabilization.sh

validate-updates: ## Validate compliance with update standards
	@echo "Running update compliance check..."
	@chmod +x scripts/validate_updates.sh
	@./scripts/validate_updates.sh

clean: ## Clean build artifacts
	flutter clean
	rm -rf build/
	rm -rf .dart_tool/
