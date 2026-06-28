#!/bin/bash
# Complete release script for StarCraftKit

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.1.0"
    exit 1
fi

VERSION=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "🚀 Releasing StarCraftKit version $VERSION"
echo "========================================"

# Ensure we're on master and up to date
echo "📋 Checking git status..."
cd "$PROJECT_ROOT"
git checkout master
git pull origin master

# Make sure working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working directory is not clean. Please commit or stash changes."
    exit 1
fi

# Create and push tag
echo "🏷️  Creating git tag..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

echo "⏳ Waiting for GitHub release to be created..."
echo "   (GitHub Actions will build the release)"
sleep 5

# Wait for the release to be available
echo "🔍 Checking for release availability..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s -f -I "https://github.com/guitaripod/StarCraftKit/archive/refs/tags/$VERSION.tar.gz" > /dev/null 2>&1; then
        echo "✅ Release is available!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "   Waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 10
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "❌ Timeout waiting for release. Please check GitHub Actions."
    exit 1
fi

# Update AUR package
echo ""
echo "📦 Updating AUR package..."
"$SCRIPT_DIR/update-aur.sh" "$VERSION"

# Push the AUR update commit
echo "📤 Pushing AUR update to main repo..."
git push origin master

echo ""
echo "✅ Release $VERSION completed successfully!"
echo ""
echo "Summary:"
echo "- GitHub release created"
echo "- AUR package updated"
echo "- Users can now update with: yay -Syu starcraft-cli"