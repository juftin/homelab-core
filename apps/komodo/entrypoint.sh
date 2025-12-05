#!/usr/bin/env bash

set -e

# Variable Declarations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
BIN_DIR="${ROOT_DIR}/bin"
MISE_VERSION="v2025.12.0"
MISE_BINARY="${BIN_DIR}/mise"

function install_mise() {
  echo "Installing MISE..."
  # Install MISE via official install script
  curl -sSL https://mise.run | \
    MISE_INSTALL_PATH="${MISE_BINARY}" \
    MISE_VERSION="${MISE_VERSION}" \
    MISE_INSTALL_HELP="0" \
    MISE_QUIET="1" \
    sh
  # Add MISE to PATH
  echo "MISE installed at ${MISE_BINARY}"
  export PATH="${BIN_DIR}:${PATH}"
  mise --version
}

# Install MISE if not present
if ! command -v mise &> /dev/null; then
  install_mise
fi

# Execute Passed Commands
if [ ${#} -eq 0 ]; then
  exec core
else
  exec "${@}"
fi
