#!/usr/bin/env bash
set -euo pipefail

repo_root="$( "$(dirname -- "${BASH_SOURCE[0]}")/../../../bin/cicero-root" )"
cd -- "${repo_root}"

MODEL_NAME="cicero-clawbot"
MODEL_TAG="${MODEL_NAME}:latest"
MODELFILE="pipelines/ollama/modelfiles/Modelfile-cicero-clawbot"
OLLAMA_URL="http://127.0.0.1:11434"

if [[ ! -f "${MODELFILE}" ]]; then
  echo "error: missing Modelfile: ${MODELFILE}" >&2
  exit 1
fi

if ! curl -fsS "${OLLAMA_URL}/api/tags" >/dev/null; then
  echo "error: Ollama not reachable at ${OLLAMA_URL}." >&2
  echo "  start Ollama, then retry." >&2
  exit 1
fi

base_model="$(
  awk '
    toupper($1)=="FROM" { print $2; exit }
  ' "${MODELFILE}"
)"

if [[ -z "${base_model}" ]]; then
  echo "error: could not parse base model FROM line in ${MODELFILE}" >&2
  exit 1
fi

# `ollama list` typically prints NAME as the first column.
if ! bin/ollama list | awk 'NR>1{print $1}' | grep -Fxq "${base_model}"; then
  echo "error: base model '${base_model}' not present in 'ollama list'." >&2
  echo "  edit ${MODELFILE} to reference an installed model, or pull it first." >&2
  exit 1
fi

bin/ollama create "${MODEL_NAME}" -f "${MODELFILE}"

echo
echo "created: ${MODEL_TAG}"
echo "next: bin/ollama run ${MODEL_TAG} \"Reply with only: OK\""
