#!/bin/bash
# Script to create initial AUR package

set -e

echo "Creating initial AUR package for starcraft-cli..."

# First, create the package on AUR
echo "Creating package on AUR server..."
ssh aur@aur.archlinux.org setup-repo starcraft-cli || {
    echo "Failed to create package. It may already exist."
}

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone the newly created (empty) repository
echo "Cloning empty repository..."
git clone ssh://aur@aur.archlinux.org/starcraft-cli.git
cd starcraft-cli

# Copy PKGBUILD from your repo
echo "Copying package files..."
cp ~/Dev/swift/StarCraftKit/aur/starcraft-cli/PKGBUILD .
cp ~/Dev/swift/StarCraftKit/aur/starcraft-cli/.SRCINFO .

# Configure git
git config user.name "guitaripod"
git config user.email "guitaripod@gmail.com"

# Add files and commit
git add PKGBUILD .SRCINFO
git commit -m "Initial commit"

# Push to create the package
echo "Pushing to AUR..."
git push -u origin master

echo "✅ AUR package created successfully!"
echo "Check https://aur.archlinux.org/packages/starcraft-cli"

# Clean up
cd -
rm -rf "$TEMP_DIR"