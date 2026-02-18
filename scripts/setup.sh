#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

echo "🔍 Checking dependencies..."

ensure_formula() {
  local cmd_name="$1"
  local formula_name="$2"

  if command -v "$cmd_name" >/dev/null 2>&1; then
    echo "✅ $cmd_name already installed"
    return 0
  fi

  echo "⬇️  Installing $cmd_name..."

  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew is not installed. Please install Homebrew first to proceed: https://brew.sh"
    exit 1
  fi

  if ! brew list --formula "$formula_name" >/dev/null 2>&1; then
    brew install "$formula_name"
  fi

  if command -v "$cmd_name" >/dev/null 2>&1; then
    echo "✅ $cmd_name installed"
  else
    echo "❌ Failed to install $cmd_name"
    exit 1
  fi
}

ensure_formula xcodegen xcodegen

echo ""
echo "📦 Generating Xcode project..."
xcodegen
echo "✅ Xcode project generated successfully!"

if [ ! -f Signing.xcconfig ]; then
  echo ""
  echo "🔑 Creating Signing.xcconfig from template..."
  cp Signing.xcconfig.example Signing.xcconfig
  echo "✅ Signing.xcconfig created. Open it and set your DEVELOPMENT_TEAM."
  echo "   Get your Team ID: https://developer.apple.com/account#MembershipDetailsCard"
else
  echo "✅ Signing.xcconfig already exists"
fi

echo ""
echo "🎉 Setup complete! Open Luma.xcodeproj in Xcode and build (⌘R)."
