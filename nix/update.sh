#!/usr/bin/env bash
# Update nix/version.json to the latest GitHub release (or the tag given as $1).
# Needs: curl, jq, nix (with nix-command enabled).
set -euo pipefail

cd "$(dirname "$0")"
file=version.json

repo=$(jq -r .repo "$file")
current=$(jq -r .tag "$file")

auth=()
if [[ -n "${GH_TOKEN:-}" ]]; then
  auth=(-H "Authorization: Bearer $GH_TOKEN")
fi

tag="${1:-$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)}"

# nix system -> asset name used by .github/workflows/build.yml
declare -A assets=(
  [x86_64-linux]=linux-amd64
  [aarch64-linux]=linux-arm64
  [armv7l-linux]=linux-arm-v7
)

missing_hash=$(jq -r '[.hashes[] | select(. == "")] | length' "$file")
if [[ "$tag" == "$current" && "$missing_hash" == "0" ]]; then
  echo "Already at $tag"
  exit 0
fi

# The build workflow uploads assets after the release is created; if they are
# not all there yet, do nothing and let the next run pick it up.
for system in "${!assets[@]}"; do
  url="https://github.com/$repo/releases/download/$tag/rclone-${assets[$system]}.zip"
  if ! curl -fsILo /dev/null "$url"; then
    echo "Asset not available yet: $url"
    exit 0
  fi
done

tmp=$(mktemp)
jq --arg tag "$tag" '.tag = $tag' "$file" > "$tmp"

for system in "${!assets[@]}"; do
  url="https://github.com/$repo/releases/download/$tag/rclone-${assets[$system]}.zip"
  hash=$(nix --extra-experimental-features 'nix-command flakes' \
    store prefetch-file --json "$url" | jq -r .hash)
  jq --arg s "$system" --arg h "$hash" '.hashes[$s] = $h' "$tmp" > "$tmp.new"
  mv "$tmp.new" "$tmp"
done

mv "$tmp" "$file"
echo "Updated to $tag"
