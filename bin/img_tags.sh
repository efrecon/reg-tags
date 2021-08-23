#!/usr/bin/env sh

# Shell sanity
set -eu

ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
# shellcheck disable=SC1091
. "${ROOT_DIR}/../image_tags.sh"

# Call function with same name as script
SCRIPT=$(basename "$0")
"${SCRIPT%.*}" "$@"