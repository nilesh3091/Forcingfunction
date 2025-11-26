#!/bin/bash

# Script to archive ForcingFunction app for App Store submission
# Usage: ./archive_for_appstore.sh

set -e  # Exit on error

PROJECT_NAME="ForcingFunction"
SCHEME_NAME="ForcingFunction"
WORKSPACE_PATH="${PROJECT_NAME}.xcodeproj"
ARCHIVE_PATH="./build/ForcingFunction.xcarchive"
EXPORT_PATH="./build/AppStoreExport"
EXPORT_OPTIONS_PLIST="./ExportOptions.plist"

echo "🚀 Starting App Store archive process for ${PROJECT_NAME}..."
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild clean -project "${WORKSPACE_PATH}" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release

# Create build directory if it doesn't exist
mkdir -p ./build

# Archive the app
echo ""
echo "📦 Archiving ${PROJECT_NAME}..."
xcodebuild archive \
    -project "${WORKSPACE_PATH}" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=iOS" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=NX76YKXPM7

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Archive created successfully at: ${ARCHIVE_PATH}"
    echo ""
    echo "📋 Next steps:"
    echo "1. Open Xcode"
    echo "2. Go to Window > Organizer (or press Cmd+Shift+9)"
    echo "3. Select your archive"
    echo "4. Click 'Distribute App'"
    echo "5. Choose 'App Store Connect'"
    echo "6. Follow the prompts to upload"
    echo ""
    echo "Alternatively, you can use the command line:"
    echo "xcrun altool --upload-app --type ios --file <path-to-ipa> --apiKey <your-api-key> --apiIssuer <your-issuer-id>"
    echo ""
else
    echo ""
    echo "❌ Archive failed. Please check the errors above."
    exit 1
fi



