SHELL := /bin/bash

NOTARY_PROFILE ?= minute-notary
DIST_PROFILE ?=
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
ENABLE_NOTARIZATION ?=
CREATE_DMG ?=
CREATE_ZIP ?=
GENERATE_APPCAST ?=
MINUTE_ENABLE_UPDATER ?=
MINUTE_SU_FEED_URL ?=
MINUTE_SWIFT_DISTRIBUTION_FLAG ?=
MINUTE_APP_ENTITLEMENTS_FILE ?=
MINUTE_HELPER_ENTITLEMENTS_FILE ?=
MINUTE_WHISPER_SERVICE_ENTITLEMENTS ?=

.PHONY: help release appcast archive test test-all

help:
	@echo "Minute release targets"
	@echo ""
	@echo "Required profile: DIST_PROFILE=app-store|direct"
	@echo ""
	@echo "Examples:"
	@echo "  make release DIST_PROFILE=direct ARCHIVE=/path/to/Minute.xcarchive"
	@echo "  make release DIST_PROFILE=app-store ARCHIVE=/path/to/Minute.xcarchive"
	@echo "  make appcast DIST_PROFILE=direct OUTPUT_DIR=updates"
	@echo ""
	@echo "Optional overrides:"
	@echo "  ENABLE_NOTARIZATION=0 (skip direct-profile notarization for dry-runs)"
	@echo "  CREATE_DMG=0 CREATE_ZIP=0 GENERATE_APPCAST=0 (artifact dry-run controls)"
	@echo "  MINUTE_ENABLE_UPDATER=YES|NO"
	@echo "  MINUTE_SU_FEED_URL=<url>"
	@echo "  MINUTE_SWIFT_DISTRIBUTION_FLAG=-DMINUTE_DISTRIBUTION_*"
	@echo "  MINUTE_APP_ENTITLEMENTS_FILE=Minute/Sources/App/Minute*.entitlements"

release:
	@set -e; \
	if [ -z "$(DIST_PROFILE)" ]; then \
	  echo "error: DIST_PROFILE is required (app-store|direct)" >&2; \
	  exit 1; \
	fi; \
	. scripts/release-profile.sh; \
	require_dist_profile "$(DIST_PROFILE)"; \
	if [ -z "$(ARCHIVE)" ]; then \
	  $(MAKE) archive DIST_PROFILE="$(DIST_PROFILE)" ARCHIVE="$(ARCHIVE_PATH)" SCHEME="$(SCHEME)" CONFIGURATION="$(CONFIGURATION)" WORKSPACE="$(WORKSPACE)" PROJECT="$(PROJECT)" MINUTE_ENABLE_UPDATER="$(MINUTE_ENABLE_UPDATER)" MINUTE_SU_FEED_URL="$(MINUTE_SU_FEED_URL)" MINUTE_SWIFT_DISTRIBUTION_FLAG="$(MINUTE_SWIFT_DISTRIBUTION_FLAG)" MINUTE_APP_ENTITLEMENTS_FILE="$(MINUTE_APP_ENTITLEMENTS_FILE)" MINUTE_HELPER_ENTITLEMENTS_FILE="$(MINUTE_HELPER_ENTITLEMENTS_FILE)" MINUTE_WHISPER_SERVICE_ENTITLEMENTS="$(MINUTE_WHISPER_SERVICE_ENTITLEMENTS)"; \
	  archive_to_use="$(ARCHIVE_PATH)"; \
	else \
	  archive_to_use="$(ARCHIVE)"; \
	fi; \
	DIST_PROFILE="$(DIST_PROFILE)" \
	NOTARY_PROFILE="$(NOTARY_PROFILE)" \
	OUTPUT_DIR="$(OUTPUT_DIR)" \
	ENABLE_NOTARIZATION="$(ENABLE_NOTARIZATION)" \
	CREATE_DMG="$(CREATE_DMG)" \
	CREATE_ZIP="$(CREATE_ZIP)" \
	GENERATE_APPCAST="$(GENERATE_APPCAST)" \
	APPCAST_DOWNLOAD_URL_PREFIX="$(APPCAST_DOWNLOAD_URL_PREFIX)" \
	APPCAST_DEST="$(APPCAST_DEST)" \
	SPARKLE_APPCAST_ARGS="$(SPARKLE_APPCAST_ARGS)" \
	scripts/release-notarize.sh "$$archive_to_use"

appcast:
	DIST_PROFILE="$(if $(DIST_PROFILE),$(DIST_PROFILE),direct)" scripts/generate-appcast.sh "$(OUTPUT_DIR)" "$(APPCAST_DOWNLOAD_URL_PREFIX)"

archive:
	@set -e; \
	if [ -z "$(ARCHIVE)" ]; then \
	  echo "Usage: make archive ARCHIVE=/path/to/Minute.xcarchive"; \
	  exit 1; \
	fi; \
	if [ -z "$(DIST_PROFILE)" ]; then \
	  echo "error: DIST_PROFILE is required (app-store|direct)" >&2; \
	  exit 1; \
	fi; \
	. scripts/release-profile.sh; \
	require_dist_profile "$(DIST_PROFILE)"; \
	minute_enable_updater="$(MINUTE_ENABLE_UPDATER)"; \
	if [ -z "$$minute_enable_updater" ]; then minute_enable_updater="$$(profile_default_updater_enabled "$(DIST_PROFILE)")"; fi; \
	minute_su_feed_url="$(MINUTE_SU_FEED_URL)"; \
	if [ -z "$$minute_su_feed_url" ]; then minute_su_feed_url="$$(profile_default_su_feed_url "$(DIST_PROFILE)")"; fi; \
	minute_swift_distribution_flag="$(MINUTE_SWIFT_DISTRIBUTION_FLAG)"; \
	if [ -z "$$minute_swift_distribution_flag" ]; then minute_swift_distribution_flag="$$(profile_default_swift_distribution_flag "$(DIST_PROFILE)")"; fi; \
	minute_app_entitlements_file="$(MINUTE_APP_ENTITLEMENTS_FILE)"; \
	if [ -z "$$minute_app_entitlements_file" ]; then minute_app_entitlements_file="$$(profile_default_app_entitlements "$(DIST_PROFILE)")"; fi; \
	minute_helper_entitlements_file="$(MINUTE_HELPER_ENTITLEMENTS_FILE)"; \
	if [ -z "$$minute_helper_entitlements_file" ]; then minute_helper_entitlements_file="$$(profile_default_helper_entitlements)"; fi; \
	minute_whisper_service_entitlements="$(MINUTE_WHISPER_SERVICE_ENTITLEMENTS)"; \
	if [ -z "$$minute_whisper_service_entitlements" ]; then minute_whisper_service_entitlements="$$(profile_default_whisper_service_entitlements)"; fi; \
	if [ -d "$(WORKSPACE)" ]; then \
	  xcodebuild -workspace "$(WORKSPACE)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination "generic/platform=macOS" -archivePath "$(ARCHIVE)" MINUTE_DISTRIBUTION_PROFILE="$(DIST_PROFILE)" MINUTE_ENABLE_UPDATER="$$minute_enable_updater" MINUTE_SU_FEED_URL="$$minute_su_feed_url" MINUTE_SWIFT_DISTRIBUTION_FLAG="$$minute_swift_distribution_flag" MINUTE_APP_ENTITLEMENTS_FILE="$$minute_app_entitlements_file" MINUTE_HELPER_ENTITLEMENTS_FILE="$$minute_helper_entitlements_file" MINUTE_WHISPER_SERVICE_ENTITLEMENTS="$$minute_whisper_service_entitlements" archive; \
	elif [ -d "$(PROJECT)" ]; then \
	  xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination "generic/platform=macOS" -archivePath "$(ARCHIVE)" MINUTE_DISTRIBUTION_PROFILE="$(DIST_PROFILE)" MINUTE_ENABLE_UPDATER="$$minute_enable_updater" MINUTE_SU_FEED_URL="$$minute_su_feed_url" MINUTE_SWIFT_DISTRIBUTION_FLAG="$$minute_swift_distribution_flag" MINUTE_APP_ENTITLEMENTS_FILE="$$minute_app_entitlements_file" MINUTE_HELPER_ENTITLEMENTS_FILE="$$minute_helper_entitlements_file" MINUTE_WHISPER_SERVICE_ENTITLEMENTS="$$minute_whisper_service_entitlements" archive; \
	else \
	  echo "error: no workspace or project found" >&2; \
	  exit 1; \
	fi; \
	if [ "$(DIST_PROFILE)" = "app-store" ]; then \
	  MINUTE_HELPER_ENTITLEMENTS_FILE="$$minute_helper_entitlements_file" scripts/normalize-app-store-archive.sh "$(ARCHIVE)"; \
	fi

test:
	xcodebuild -workspace "$(WORKSPACE)" -scheme MinuteCore -configuration Debug test -destination "platform=macOS"

test-all:
	xcodebuild -workspace "$(WORKSPACE)" -scheme Minute -configuration Debug test
