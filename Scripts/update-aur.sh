#!/bin/bash
# Script to update AUR package after a new release

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.1.0"
    exit 1
fi

VERSION=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
AUR_DIR="$PROJECT_ROOT/aur/starcraft-cli"
TEMP_DIR="$PROJECT_ROOT/aur-temp"

echo "🚀 Updating AUR package to version $VERSION"

# Get the source tarball checksum
echo "📦 Getting checksum for source tarball..."
CHECKSUM=$(curl -sL "https://github.com/guitaripod/StarCraftKit/archive/refs/tags/$VERSION.tar.gz" | sha256sum | cut -d' ' -f1)
echo "✅ Checksum: $CHECKSUM"

# Update PKGBUILD
echo "📝 Updating PKGBUILD..."
cd "$AUR_DIR"
sed -i "s/pkgver=.*/pkgver=$VERSION/" PKGBUILD
sed -i "s/pkgrel=.*/pkgrel=1/" PKGBUILD
sed -i "s/sha256sums=.*/sha256sums=('$CHECKSUM')/" PKGBUILD

# Clone AUR repo
echo "📥 Cloning AUR repository..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
git clone ssh://aur@aur.archlinux.org/starcraft-cli.git

# Copy updated PKGBUILD
echo "📋 Copying updated files..."
cd starcraft-cli
cp "$AUR_DIR/PKGBUILD" .

# Generate .SRCINFO
echo "🔧 Generating .SRCINFO..."
makepkg --printsrcinfo > .SRCINFO

# Commit and push
echo "📤 Pushing to AUR..."
git add PKGBUILD .SRCINFO
git commit -m "Update to $VERSION"
git push

# Clean up
echo "🧹 Cleaning up..."
cd "$PROJECT_ROOT"
rm -rf "$TEMP_DIR"

# Commit to main repo
echo "💾 Committing to main repository..."
cd "$PROJECT_ROOT"
git add "$AUR_DIR/PKGBUILD"
git commit -m "chore: update AUR package to $VERSION" || echo "No changes to commit"

echo "✅ AUR package updated successfully!"
echo ""
echo "Next steps:"
echo "1. Push to GitHub: git push origin master"
echo "2. Users can update with: yay -Syu starcraft-cli"