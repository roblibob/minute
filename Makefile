NOTARY_PROFILE ?= minute-notary
ARCHIVE ?=
ARCHIVE_PATH ?= $(PWD)/build/Minute.xcarchive
SCHEME ?= Minute
CONFIGURATION ?= Release
WORKSPACE ?= Minute.xcworkspace
PROJECT ?= Minute.xcodeproj
OUTPUT_DIR ?= updates
APPCAST_DOWNLOAD_URL_PREFIX ?=
APPCAST_DEST ?= $(OUTPUT_DIR)/appcast.xml
SPARKLE_APPCAST_ARGS ?=

.PHONY: release appcast archive

release:
	@set -e; \
	if [ -z "$(ARCHIVE)" ]; then \
	  $(MAKE) archive ARCHIVE="$(ARCHIVE_PATH)" SCHEME="$(SCHEME)" CONFIGURATION="$(CONFIGURATION)" WORKSPACE="$(WORKSPACE)" PROJECT="$(PROJECT)"; \
	  archive_to_use="$(ARCHIVE_PATH)"; \
	else \
	  archive_to_use="$(ARCHIVE)"; \
	fi; \
	NOTARY_PROFILE="$(NOTARY_PROFILE)" \
	OUTPUT_DIR="$(OUTPUT_DIR)" \
	APPCAST_DOWNLOAD_URL_PREFIX="$(APPCAST_DOWNLOAD_URL_PREFIX)" \
	APPCAST_DEST="$(APPCAST_DEST)" \
	SPARKLE_APPCAST_ARGS="$(SPARKLE_APPCAST_ARGS)" \
	scripts/release-notarize.sh "$$archive_to_use"

appcast:
	scripts/generate-appcast.sh "$(OUTPUT_DIR)" "$(APPCAST_DOWNLOAD_URL_PREFIX)"

archive:
	@if [ -z "$(ARCHIVE)" ]; then \
	  echo "Usage: make archive ARCHIVE=/path/to/Minute.xcarchive"; \
	  exit 1; \
	fi
	@if [ -d "$(WORKSPACE)" ]; then \
	  xcodebuild -workspace "$(WORKSPACE)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination "generic/platform=macOS" -archivePath "$(ARCHIVE)" archive; \
	elif [ -d "$(PROJECT)" ]; then \
	  xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination "generic/platform=macOS" -archivePath "$(ARCHIVE)" archive; \
	else \
	  echo "error: no workspace or project found" >&2; \
	  exit 1; \
	fi
