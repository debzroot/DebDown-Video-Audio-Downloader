#!/bin/bash
# Build script for DebDown+
# Run from project root: ./build.sh

set -e

echo "🔧 Building DebDown+ APK..."

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Install Flutter first."
    exit 1
fi

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building APK (release)..."
flutter build apk --release --split-per-abi

echo ""
echo "✅ Build selesai!"
echo "📁 APK locations:"
ls -la build/app/outputs/flutter-apk/

echo ""
echo "📦 Universal APK (recommended):"
ls -la build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || echo "Tidak ada universal, pakai split APK"