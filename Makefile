.PHONY: generate build run clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Release build

run: generate
	xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug build 2>&1 | tail -5
	@open "$$(xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage -configuration Debug -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}')/ClaudeUsage.app"

clean:
	rm -rf ClaudeUsage.xcodeproj DerivedData build
