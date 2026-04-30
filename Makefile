.PHONY: run dev test coverage build clean deps

APP := MacMicWidget
SWIFT := swift

run:
	$(SWIFT) run $(APP)

dev:
	@command -v watchexec >/dev/null 2>&1 || (echo "watchexec not found. Install: brew install watchexec" && exit 1)
	watchexec --exts swift --watch Sources --watch Tests --watch Package.swift --restart -- "$(SWIFT) run $(APP)"

test:
	$(SWIFT) test

coverage:
	scripts/test/coverage.sh

build:
	$(SWIFT) build

clean:
	$(SWIFT) package clean

deps:
	$(SWIFT) package resolve
