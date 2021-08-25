#!/usr/bin/env sh

# Shell sanity
set -eu

ROOT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
# shellcheck disable=SC1091
[ -f "${ROOT_DIR}/../image_tags.sh" ] && . "${ROOT_DIR}/../image_tags.sh"
# shellcheck disable=SC1091
[ -f "${ROOT_DIR}/../lib/image_tags.sh" ] && . "${ROOT_DIR}/../lib/image_tags.sh"

# Call function with same name as script
SCRIPT=$(basename "$0")

is_function() {
  type "$1" | sed "s/$1//" | grep -qwi function
}
if is_function "${SCRIPT%.*}"; then
  "${SCRIPT%.*}" "$@"
elif is_function "$1"; then
  _fn=$1
  shift
  "$_fn" "$@"
elif is_function "img_$1"; then
  _fn=img_$1
  shift
  "$_fn" "$@"
else
  echo "${SCRIPT%.*} is not implemented" >&2
  exit 1
fi