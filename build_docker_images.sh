#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root"

empty_context="$(mktemp -d)"
trap 'rm -rf "$empty_context"' EXIT

images=(
    "local/hic-prep-input:1.0            docker/Dockerfile.prep_input      $empty_context"
    "local/hic-tad-arrowhead:1.0         docker/Dockerfile.arrowhead       $empty_context"
    "local/hic-tad-topdom:1.0            docker/Dockerfile.topdom          $empty_context"
    "local/hic-tad-di:1.0                docker/Dockerfile.di              docker/di_scripts"
    "local/hic-tad-mstd:1.0              docker/Dockerfile.mstd            $empty_context"
    "local/hic-tad-ontad:1.0             docker/Dockerfile.ontad           $empty_context"
    "local/hic-tad-spectraltad:1.0       docker/Dockerfile.spectraltad     $empty_context"
    "local/hic-tad-dedoc:1.0             docker/Dockerfile.dedoc           $empty_context"
    "local/hic-tad-lpad:1.0              docker/Dockerfile.lpad            $empty_context"
    "local/hic-tad-clean_results:1.0     docker/Dockerfile.clean_results   $empty_context"
    "local/hic-tad-consensus_tads:1.0    docker/Dockerfile.consensus_tads  $empty_context"
)

for entry in "${images[@]}"; do
    read -r tag dockerfile context <<< "$entry"
    echo "==> Building $tag"
    docker build -t "$tag" -f "$dockerfile" "$context"
done

echo "==> All ${#images[@]} images built successfully"
