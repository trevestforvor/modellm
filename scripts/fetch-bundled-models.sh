#!/usr/bin/env bash
# Fetches GGUF models that get bundled into simulator builds.
# Models are gitignored — run this after a fresh clone if you need simulator
# LLM testing. Device builds use HF Hub download via DownloadService and
# don't need these.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/../ModelRunner/Resources/BundledModels"
mkdir -p "$DEST_DIR"

declare -a MODELS=(
  # name|url
  # Q8_0 (not Q4_K_M) — tiny models lose too much quality at 4-bit; SmolLM2-360M is
  # incoherent below Q5. Pay the +110 MB for usable output.
  "SmolLM2-360M-Instruct-Q8_0.gguf|https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q8_0.gguf"
)

for entry in "${MODELS[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  dest="$DEST_DIR/$name"
  if [[ -f "$dest" ]]; then
    echo "✓ $name already present (skip)"
    continue
  fi
  echo "↓ Downloading $name..."
  curl -L --fail --progress-bar -o "$dest" "${url}?download=true"
  echo "✓ $name fetched ($(du -h "$dest" | cut -f1))"
done

echo "Done. Bundled models: $DEST_DIR"
