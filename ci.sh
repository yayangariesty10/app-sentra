#!/usr/bin/env bash
# ci.sh - pipeline CI lokal: lint -> test -> build -> smoke
# Pemakaian: ./ci.sh 
#            ./ci.sh lint test 
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
IMAGE="${IMAGE:-sentra}"

TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo dev)}"
PORT_UJI="${PORT_UJI:-18080}"
NAMA_UJI="sentra-ci-$$"
RINGKASAN=()
bersihkan() { docker rm -f "$NAMA_UJI" >/dev/null 2>&1 || true; }
trap bersihkan EXIT
laporan() {
    printf '\n===== RINGKASAN PIPELINE (%s:%s) =====\n' "$IMAGE" "$TAG"
    printf '%s\n' "${RINGKASAN[@]}"
}
# PENTING: setiap command di dalam stage diakhiri '|| return 1'.
# Function ini dipanggil di dalam 'if', dan di sana set -e TIDAK berlaku.
lint_code() {
    local skrip=(./*.sh)

    if [[ -d hooks ]]; then skrip+=(hooks/*); fi
    shellcheck "${skrip[@]}" || return 1
    python3 -m py_compile src/app.py || return 1

}
test_unit() {
    [[ -d .venv ]] || python3 -m venv .venv || return 1
    .venv/bin/pip install -q -r requirements.txt \
        -r requirements-dev.txt || return 1
    .venv/bin/python -m pytest -q tests || return 1
}
build_image() {

    docker build -q -t "$IMAGE:$TAG" . >/dev/null || return 1
    echo "image siap: $IMAGE:$TAG"
}
smoke_test() {
    docker run -d --name "$NAMA_UJI" -p "$PORT_UJI:5000" \
        "$IMAGE:$TAG" >/dev/null || return 1
    for _ in $(seq 1 15); do
        if curl -fsS "http://127.0.0.1:$PORT_UJI/health" >/dev/null 2>&1; then
            echo "health check OK"; return 0
        fi
        sleep 1
    done
    docker logs "$NAMA_UJI" 2>&1 | tail -n 20 >&2
    return 1
}
stage() {
    local nama="$1" fn="$2" mulai durasi
    printf '\n==> [%s]\n' "$nama"
    mulai=$(date +%s)
    if "$fn"; then
        durasi=$(( $(date +%s) - mulai ))
        RINGKASAN+=("$(printf '%-6s LULUS %3ss' "$nama" "$durasi")")
    else
        durasi=$(( $(date +%s) - mulai ))
        RINGKASAN+=("$(printf '%-6s GAGAL %3ss' "$nama" "$durasi")")
        laporan
        echo "Pipeline BERHENTI di stage '$nama'." >&2
        exit 1
    fi
}
[[ $# -gt 0 ]] || set -- lint test build smoke
for s in "$@"; do
    case "$s" in
        lint)  stage lint  lint_code ;;

        test)  stage test  test_unit ;;
        build) stage build build_image ;;
        smoke) stage smoke smoke_test ;;
        *) echo "Stage tidak dikenal: $s" >&2; exit 64 ;;
    esac
done
laporan
echo "Pipeline LULUS."

