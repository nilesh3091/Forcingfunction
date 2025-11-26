# App Store Upload Guide for ForcingFunction

This guide will help you upload your app to App Store Connect for TestFlight testing.

## Prerequisites

1. **Apple Developer Account**: Ensure you have an active Apple Developer Program membership ($99/year)
2. **App Store Connect Access**: Your Apple ID must have access to App Store Connect
3. **Xcode**: Latest version installed
4. **App Record**: Create an app record in App Store Connect if you haven't already

## Step 1: Create App Record in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: ForcingFunction (or your preferred name)
   - **Primary Language**: English
   - **Bundle ID**: Select `NileshKumar.ForcingFunctionApp` (or create it if needed)
   - **SKU**: A unique identifier (e.g., `forcingfunction-001`)
   - **User Access**: Full Access (or as needed)

## Step 2: Archive the App

### Option A: Using Xcode (Recommended)

1. Open `ForcingFunction.xcodeproj` in Xcode
2. Select **Any iOS Device** (or a connected device) from the device selector
3. Go to **Product** → **Archive**
4. Wait for the archive to complete
5. The Organizer window will open automatically

### Option B: Using Command Line Script

1. Make the script executable:
   ```bash
   chmod +x archive_for_appstore.sh
   ```

2. Run the script:
   ```bash
   ./archive_for_appstore.sh
   ```

3. The archive will be created in `./build/ForcingFunction.xcarchive`

## Step 3: Upload to App Store Connect

### Using Xcode Organizer (Easiest)

1. In Xcode, go to **Window** → **Organizer** (or press `Cmd+Shift+9`)
2. Select your archive
3. Click **Distribute App**
4. Choose **App Store Connect**
5. Click **Next**
6. Select **Upload**
7. Click **Next**
8. Review the app information
9. Click **Upload**
10. Wait for the upload to complete (this may take several minutes)

### Using Command Line (Alternative)

If you prefer command line, you can export and upload:

```bash
# Export IPA from archive
xcodebuild -exportArchive \
    -archivePath ./build/ForcingFunction.xcarchive \
    -exportPath ./build/AppStoreExport \
    -exportOptionsPlist ExportOptions.plist

# Upload using altool (requires API key)
xcrun altool --upload-app \
    --type ios \
    --file ./build/AppStoreExport/ForcingFunction.ipa \
    --apiKey YOUR_API_KEY \
    --apiIssuer YOUR_ISSUER_ID
```

Or use the newer `xcrun notarytool` if you have an API key set up.

## Step 4: Process Build in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app
3. Go to **TestFlight** tab
4. Wait for processing to complete (usually 10-30 minutes)
5. Once processed, you'll see the build under **Builds**

## Step 5: Set Up TestFlight Testing

1. In App Store Connect, go to **TestFlight** tab
2. Select your build
3. Add test information (optional):
   - **What to Test**: Describe what testers should focus on
   - **Feedback Email**: Your email for test feedback
4. Add **Internal Testers** (up to 100):
   - Go to **Internal Testing** section
   - Click **+** to add testers
   - Add email addresses of team members
5. Add **External Testers** (optional, requires Beta App Review):
   - Go to **External Testing** section
   - Create a new group or use existing
   - Add testers (up to 10,000)
   - Submit for Beta App Review

## Step 6: Testers Install via TestFlight

1. Testers will receive an email invitation
2. They need to install **TestFlight** app from App Store
3. Open the invitation email on their iOS device
4. Tap **Start Testing** or open the link
5. TestFlight will open and they can install your app

## Troubleshooting

### Common Issues

1. **"No accounts with App Store Connect access"**
   - Ensure you're signed in with the correct Apple ID in Xcode
   - Go to Xcode → Settings → Accounts → Add your Apple ID

2. **"No valid signing certificates"**
   - Xcode should automatically manage certificates
   - If issues persist, go to Xcode → Settings → Accounts → Select your team → Download Manual Profiles

3. **"Bundle identifier conflicts"**
   - Ensure the bundle ID matches exactly: `NileshKumar.ForcingFunctionApp`
   - Check App Store Connect that the bundle ID is registered

4. **"Invalid Bundle"**
   - Ensure all required app icons are present
   - Check that the deployment target matches your app settings (iOS 18.6)

5. **"Missing Compliance"**
   - You may need to answer export compliance questions in App Store Connect
   - Go to your app → App Information → Answer the questions

### Build Settings Check

Before archiving, verify:
- ✅ Development Team: `NX76YKXPM7`
- ✅ Bundle Identifier: `NileshKumar.ForcingFunctionApp`
- ✅ Version: 1.0
- ✅ Build: 1 (increment for each upload)
- ✅ Code Signing: Automatic

## Incrementing Build Number

For each new upload, increment the build number:
1. In Xcode, select your project in the navigator
2. Select the **ForcingFunction** target
3. Go to **General** tab
4. Increment **Build** number (e.g., 1 → 2)
5. Or edit `project.pbxproj` and change `CURRENT_PROJECT_VERSION`

## Additional Resources

- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Notes

- First upload may take longer to process
- TestFlight builds expire after 90 days
- You can have multiple builds in TestFlight simultaneously
- External testing requires Beta App Review (usually 24-48 hours)

Good luck with your app submission! 🚀






