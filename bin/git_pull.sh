#!/bin/bash
set -euo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

git pull origin "${BRANCH}"

# Re-sync the (non-committed) docsearch theme from fess-themes after pulling.
# Honors FESS_THEMES_DIR / FESS_THEMES_REPO / FESS_THEMES_REF like setup.sh.
bash ./bin/setup.sh
