#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rsync -a --backup --suffix='.pre-bsdrunner' "$repo_root/dotfiles/" "$HOME/"

echo ":: Installed BSDRunner dotfiles into $HOME"
