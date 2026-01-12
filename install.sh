#!/bin/sh
set -e

REPO="tuananh131001/zccinfo"
BINARY_NAME="zig-context"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$OS" in
        darwin) OS="macos" ;;
        linux) OS="linux" ;;
        *)
            echo "Error: Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    case "$ARCH" in
        x86_64|amd64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="aarch64" ;;
        *)
            echo "Error: Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    PLATFORM="${ARCH}-${OS}"
}

# Get the latest release version
get_latest_version() {
    curl -sL "https://api.github.com/repos/${REPO}/releases/latest" | \
        grep '"tag_name":' | \
        sed -E 's/.*"([^"]+)".*/\1/'
}

# Download and install
install() {
    detect_platform

    VERSION=$(get_latest_version)
    if [ -z "$VERSION" ]; then
        echo "Error: Could not determine latest version"
        exit 1
    fi

    DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_NAME}-${PLATFORM}.tar.gz"
    CHECKSUM_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums.txt"

    echo "Installing ${BINARY_NAME} ${VERSION} for ${PLATFORM}..."

    # Create temp directory
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Download binary and checksums
    echo "Downloading from ${DOWNLOAD_URL}..."
    curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/${BINARY_NAME}.tar.gz"
    curl -sL "$CHECKSUM_URL" -o "$TMP_DIR/checksums.txt"

    # Verify checksum
    cd "$TMP_DIR"
    EXPECTED_CHECKSUM=$(grep "${BINARY_NAME}-${PLATFORM}.tar.gz" checksums.txt | awk '{print $1}')
    if command -v sha256sum > /dev/null 2>&1; then
        ACTUAL_CHECKSUM=$(sha256sum "${BINARY_NAME}.tar.gz" | awk '{print $1}')
    else
        ACTUAL_CHECKSUM=$(shasum -a 256 "${BINARY_NAME}.tar.gz" | awk '{print $1}')
    fi

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        echo "Error: Checksum verification failed"
        echo "Expected: $EXPECTED_CHECKSUM"
        echo "Actual:   $ACTUAL_CHECKSUM"
        exit 1
    fi
    echo "Checksum verified."

    # Extract and install
    tar -xzf "${BINARY_NAME}.tar.gz"
    mkdir -p "$INSTALL_DIR"
    mv "$BINARY_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    echo ""
    echo "Successfully installed ${BINARY_NAME} to ${INSTALL_DIR}/${BINARY_NAME}"

    # Check if install dir is in PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *)
            echo ""
            echo "Add ${INSTALL_DIR} to your PATH:"
            echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
            echo ""
            echo "Or add it to your shell profile (~/.bashrc, ~/.zshrc, etc.)"
            ;;
    esac
}

install
