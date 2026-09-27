#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv-build"

PYTHON="${VENV_DIR}/bin/python"
BASEROM_UNCOMPRESSED="${ROOT_DIR}/baserom_uncompressed.z64"

EXPECTED_ROM_SHA1="989a28782ed6b0bc489a1bbbd7bec355d8f2707e"
EXPECTED_DECOMPRESSED_SHA1="c176c2493d90e12d0a2b6873cfcbc611a9bea245"

echo "===== CV64 Revo build bootstrap ====="
echo "Root: ${ROOT_DIR}"
echo "Venv: ${VENV_DIR}"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/castlevania.z64" >&2
    echo >&2
    echo "Requires an original North American Castlevania 64 ROM in .z64 format." >&2
    exit 1
fi

BASEROM="$1"

if [[ ! -f "${BASEROM}" ]]; then
    echo "Error: ROM file not found:" >&2
    echo "  ${BASEROM}" >&2
    exit 1
fi

echo
echo "Validating original ROM..."

ROM_SHA1="$(sha1sum "${BASEROM}" | awk '{print $1}')"

if [[ "${ROM_SHA1}" != "${EXPECTED_ROM_SHA1}" ]]; then
    echo "Error: unsupported ROM." >&2
    echo "Expected SHA-1: ${EXPECTED_ROM_SHA1}" >&2
    echo "Found SHA-1:    ${ROM_SHA1}" >&2
    echo >&2
    echo "Use the original North American Castlevania 64 ROM in .z64 format." >&2
    exit 1
fi

echo "Original ROM SHA-1 verified."

if [[ ! -x "${PYTHON}" ]]; then
    echo
    echo "Creating Python virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi

echo
echo "Installing build dependencies..."
"${PYTHON}" -m pip install -r "${SCRIPT_DIR}/requirements-build.txt"

echo
echo "===== Build Python ====="
"${PYTHON}" --version
"${PYTHON}" -m splat --version

echo
echo "Decompressing ROM..."
"${PYTHON}" "${SCRIPT_DIR}/decompress.py" "${BASEROM}" "${BASEROM_UNCOMPRESSED}"

DECOMPRESSED_SHA1="$(sha1sum "${BASEROM_UNCOMPRESSED}" | awk '{print $1}')"

if [[ "${DECOMPRESSED_SHA1}" != "${EXPECTED_DECOMPRESSED_SHA1}" ]]; then
    rm -f "${BASEROM_UNCOMPRESSED}"
    echo "Error: decompressed ROM failed SHA-1 verification." >&2
    echo "Expected SHA-1: ${EXPECTED_DECOMPRESSED_SHA1}" >&2
    echo "Found SHA-1:    ${DECOMPRESSED_SHA1}" >&2
    exit 1
fi

echo "Decompressed ROM SHA-1 verified."

echo
echo "Bootstrap complete."
echo
echo "Use this Python for CMake:"
echo "  ${PYTHON}"
