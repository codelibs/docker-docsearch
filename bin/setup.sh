#!/bin/bash
set -euo pipefail

THEME_NAME=docsearch
THEME_DEST=./data/fess/usr/share/fess/app/themes/${THEME_NAME}

echo "Creating directories..."
mkdir -p ./data/https-portal/ssl_certs
mkdir -p ./data/fess/opt/fess
mkdir -p ./data/fess/var/lib/fess
mkdir -p ./data/fess/var/log/fess
mkdir -p ./data/fess/usr/share/fess/app/WEB-INF/plugin
mkdir -p "${THEME_DEST}"
mkdir -p ./data/opensearch/usr/share/opensearch/data
mkdir -p ./data/opensearch/usr/share/opensearch/config/dictionary

# Seed the live system.properties from the tracked template on first run.
# The live file is git-ignored so Fess can rewrite it at runtime (e.g. Admin >
# General) without causing git-pull conflicts; an existing file is preserved.
# To reset to defaults, delete it and re-run this script.
SYSTEM_PROPERTIES=./data/fess/opt/fess/system.properties
if [ ! -f "${SYSTEM_PROPERTIES}" ]; then
  echo "Creating ${SYSTEM_PROPERTIES} from template..."
  cp "${SYSTEM_PROPERTIES}.template" "${SYSTEM_PROPERTIES}"
fi

echo "Syncing '${THEME_NAME}' theme from fess-themes..."
# Source resolution:
#   FESS_THEMES_DIR  -> copy from a local fess-themes checkout (e.g. ../fess-workspace/repos/fess-themes)
#   otherwise        -> shallow clone FESS_THEMES_REPO @ FESS_THEMES_REF
FESS_THEMES_REPO="${FESS_THEMES_REPO:-https://github.com/codelibs/fess-themes.git}"
FESS_THEMES_REF="${FESS_THEMES_REF:-master}"

rm -rf "${THEME_DEST}"
mkdir -p "${THEME_DEST}"
if [ -n "${FESS_THEMES_DIR:-}" ]; then
  src="${FESS_THEMES_DIR}/themes/${THEME_NAME}"
  if [ ! -f "${src}/theme.yml" ]; then
    echo "ERROR: ${src}/theme.yml not found (check FESS_THEMES_DIR)." >&2
    exit 1
  fi
  cp -R "${src}/." "${THEME_DEST}/"
else
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  git clone --depth 1 --branch "${FESS_THEMES_REF}" "${FESS_THEMES_REPO}" "${tmpdir}/fess-themes"
  src="${tmpdir}/fess-themes/themes/${THEME_NAME}"
  if [ ! -f "${src}/theme.yml" ]; then
    echo "ERROR: ${src}/theme.yml not found in ${FESS_THEMES_REPO}@${FESS_THEMES_REF}." >&2
    exit 1
  fi
  cp -R "${src}/." "${THEME_DEST}/"
fi
echo "Theme synced to ${THEME_DEST}"

if [ "$(uname -s)" = "Linux" ] ; then
  echo "Changing an owner for directories..."
  sudo chown -R root ./data/https-portal/ssl_certs
  sudo chown -R 1001 ./data/fess/opt/fess
  sudo chown -R 1001 ./data/fess/var/lib/fess
  sudo chown -R 1001 ./data/fess/var/log/fess
  sudo chown -R 1001 ./data/fess/usr/share/fess/app/WEB-INF/plugin
  sudo chown -R 1001 ./data/fess/usr/share/fess/app/themes
  sudo chown -R 1000 ./data/opensearch/usr/share/opensearch/data
  sudo chown -R 1000 ./data/opensearch/usr/share/opensearch/config/dictionary
fi
