#!/usr/bin/env bash
set -euo pipefail

repo_root="$( "$(dirname -- "${BASH_SOURCE[0]}")/../../../bin/cicero-root" )"
cd -- "${repo_root}"

MODEL_TAG="${1:-cicero-clawbot:latest}"
PROMPTS_DIR="pipelines/ollama/evals/prompts"
RUNS_DIR="pipelines/ollama/evals/runs"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${RUNS_DIR}/${ts}"

mkdir -p "${run_dir}"

{
  echo "timestamp_utc=${ts}"
  echo "git_commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "ollama_version=$(bin/ollama --version 2>/dev/null || echo unknown)"
  echo "model_tag=${MODEL_TAG}"
} > "${run_dir}/meta.txt"

shopt -s nullglob
prompts=( "${PROMPTS_DIR}"/*.txt )
shopt -u nullglob

if [[ "${#prompts[@]}" -eq 0 ]]; then
  echo "error: no prompts found in ${PROMPTS_DIR} (*.txt)" >&2
  exit 1
fi

for p in "${prompts[@]}"; do
  name="$(basename -- "${p}" .txt)"
  out="${run_dir}/${name}.out.txt"

  prompt="$(cat -- "${p}")"
  {
    echo "=== prompt: ${p} ==="
    echo
    echo "${prompt}"
    echo
    echo "=== response ==="
    echo
    bin/ollama run "${MODEL_TAG}" "${prompt}"
    echo
  } > "${out}"
done

echo "wrote: ${run_dir}"
