NOTARY_PROFILE ?= minute-notary
ARCHIVE ?=
OUTPUT_DIR ?= updates
APPCAST_DOWNLOAD_URL_PREFIX ?=
APPCAST_DEST ?= $(OUTPUT_DIR)/appcast.xml
SPARKLE_APPCAST_ARGS ?=

.PHONY: release appcast

release:
	@if [ -z "$(ARCHIVE)" ]; then \
	  echo "Usage: make release ARCHIVE=/path/to/Minute.xcarchive"; \
	  exit 1; \
	fi
	NOTARY_PROFILE="$(NOTARY_PROFILE)" \
	OUTPUT_DIR="$(OUTPUT_DIR)" \
	APPCAST_DOWNLOAD_URL_PREFIX="$(APPCAST_DOWNLOAD_URL_PREFIX)" \
	APPCAST_DEST="$(APPCAST_DEST)" \
	SPARKLE_APPCAST_ARGS="$(SPARKLE_APPCAST_ARGS)" \
	scripts/release-notarize.sh "$(ARCHIVE)"

appcast:
	scripts/generate-appcast.sh "$(OUTPUT_DIR)" "$(APPCAST_DOWNLOAD_URL_PREFIX)"
