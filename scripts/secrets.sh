#!/usr/bin/env bash

set -e

# Determine Directory / File Locations
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPTS_DIR}")"
BIN_DIR="${ROOT_DIR}/bin"
PLATFORM="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
SOPS_VERSION="v3.11.0"
SOPS_FILENAME="sops-${SOPS_VERSION}.${PLATFORM}.${ARCH}"
SOPS_BINARY="${BIN_DIR}/${SOPS_FILENAME}"
AGE_VERSION="v1.2.1"
AGE_KEYGEN_BINARY="${BIN_DIR}/age-keygen-${AGE_VERSION}.${PLATFORM}.${ARCH}"
ENCRYPTED_FILE="${ROOT_DIR}/secrets.env.yaml"
UNENCRYPTED_FILE="${ROOT_DIR}/secrets.env"
AGE_KEY_FILE="${ROOT_DIR}/.age/key.txt"

# Logging Function
function log() {
    local log_level="${1^^}"
    local log_message=${2:?Log message is required}
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    echo "${timestamp} [${log_level}] : ${log_message}"
}

# Download AGE Keygen Binary
function download_age() {
  if [[ ! -f "${AGE_KEYGEN_BINARY}" ]]; then
      log info "Downloading AGE keygen version ${AGE_VERSION} for ${PLATFORM}-${ARCH}..."
      AGE_DOWNLOAD_URL="https://github.com/FiloSottile/age/releases/download"
      AGE_URL="${AGE_DOWNLOAD_URL}/${AGE_VERSION}/age-${AGE_VERSION}-${PLATFORM}-${ARCH}.tar.gz"
      mkdir -p "$(dirname "${AGE_KEYGEN_BINARY}")"
      curl -sSL "${AGE_URL}" | tar -xz -C "${BIN_DIR}" "age/age-keygen"
      mv "${BIN_DIR}/age/age-keygen" "${AGE_KEYGEN_BINARY}"
      chmod +x "${AGE_KEYGEN_BINARY}"
      rm -r "${BIN_DIR}/age"
      chmod +x "${AGE_KEYGEN_BINARY}"
      log info "AGE keygen downloaded and installed at ${AGE_KEYGEN_BINARY}"
  fi
}

# Download and Install SOPS Binary
function download_sops() {
  if [[ ! -f "${SOPS_BINARY}" ]]; then
      log info "Downloading SOPS version ${SOPS_VERSION} for ${PLATFORM}-${ARCH}..."
      SOPS_DOWNLOAD_URL="https://github.com/getsops/sops/releases/download"
      SOPS_URL="${SOPS_DOWNLOAD_URL}/${SOPS_VERSION}/${SOPS_FILENAME}"
      mkdir -p "$(dirname "${SOPS_BINARY}")"
      curl -sSL "${SOPS_URL}" --output "${SOPS_BINARY}"
      chmod +x "${SOPS_BINARY}"
      log info "SOPS downloaded and installed at ${SOPS_BINARY}"
  fi
}

# Generate AGE Key
function keygen() {
    if [[ ! -f "${AGE_KEY_FILE}" ]]; then
        log info "Generating new AGE key file at ${AGE_KEY_FILE}..."
        mkdir -p "$(dirname "${AGE_KEY_FILE}")"
        "${AGE_KEYGEN_BINARY}" -o "${AGE_KEY_FILE}"
        chmod 600 "${AGE_KEY_FILE}"
        log info "AGE key file generated: ${AGE_KEY_FILE}"
        log info "Make sure to back up this key file securely and update ${ROOT_DIR}/.sops.yaml"
    else
        log error "AGE key file already exists at ${AGE_KEY_FILE}"
        exit 1
    fi
}

# Validate Encryption/Decryption Keys
function validate_keys() {
    if [[ ! -f "${AGE_KEY_FILE}" ]]; then
        log error "AGE key file not found at ${AGE_KEY_FILE}"
        log info "Generate a new key file using the 'keygen' command"
        exit 1
    fi
    export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"
}

# Decrypt ${ENCRYPTED_FILE} to ${UNENCRYPTED_FILE}
function decrypt() {
    validate_keys
    ${SOPS_BINARY} decrypt "${ENCRYPTED_FILE}" --output "${UNENCRYPTED_FILE}" --output-type dotenv
    log info "Decryption complete: ${UNENCRYPTED_FILE}"
}

# Encrypt ${UNENCRYPTED_FILE} to ${ENCRYPTED_FILE}
function encrypt() {
    validate_keys
    ${SOPS_BINARY} encrypt "${UNENCRYPTED_FILE}" --output "${ENCRYPTED_FILE}" --input-type dotenv --output-type yaml
    log info "Encryption complete: ${ENCRYPTED_FILE}"
}

# Command Handling
HELP_MESSAGE="$(cat << EOF

Usage: $(basename "${0}") <command>

Commands:
  keygen     Generate a new AGE key file
  decrypt    Decrypt the secrets file
  encrypt    Encrypt the secrets file
EOF
)"
ARGUMENTS=("${@}")
FIRST_ARGUMENT="${ARGUMENTS[0]}"
case "${FIRST_ARGUMENT}" in
    "")
        log error "No command provided"
        echo "${HELP_MESSAGE}"
        exit 1
        ;;
    keygen)
        download_age
        keygen
        ;;
    decrypt)
        download_sops
        decrypt
        ;;
    encrypt)
        download_sops
        encrypt
        ;;
    *)
        log error "Unknown command: ${FIRST_ARGUMENT}"
        echo "${HELP_MESSAGE}"
        exit 1
        ;;
esac
