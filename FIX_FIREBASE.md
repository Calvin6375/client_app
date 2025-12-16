# Fix Firebase Configuration Error

## Problem
The error "Firebase not configured. Please add GoogleService-Info.plist file" appears because the `GoogleService-Info.plist` file exists in the filesystem but is not added to the Xcode project, so it's not included in the app bundle.

## Solution: Add File to Xcode Project

### Option 1: Using Xcode (Recommended)

1. **Open the Xcode workspace:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **In Xcode:**
   - In the Project Navigator (left sidebar), right-click on the **Runner** folder
   - Select **"Add Files to 'Runner'..."**
   - Navigate to and select `ios/Runner/GoogleService-Info.plist`
   - **IMPORTANT:** Check these options:
     - ✅ "Copy items if needed" (should be unchecked since file is already there)
     - ✅ "Add to targets: Runner" (MUST be checked)
   - Click **"Add"**

3. **Verify it was added:**
   - You should see `GoogleService-Info.plist` in the Runner folder in Xcode
   - Select it and check the "Target Membership" in the right panel - "Runner" should be checked

4. **Clean and rebuild:**
   ```bash
   flutter clean
   cd ios && pod install && cd ..
   flutter run
   ```

### Option 2: Using Ruby Script (if xcodeproj gem is installed)

1. **Install the xcodeproj gem (if not installed):**
   ```bash
   gem install xcodeproj
   ```

2. **Run the script:**
   ```bash
   ruby add_google_service_to_xcode.rb
   ```

3. **Clean and rebuild:**
   ```bash
   flutter clean
   cd ios && pod install && cd ..
   flutter run
   ```

### Option 3: Manual project.pbxproj Edit (Advanced - Not Recommended)

This is complex and error-prone. Only use if Options 1 and 2 don't work.

## Verification

After adding the file, run the app and check:
- The error message should no longer appear
- Firebase should initialize successfully (check console logs)
- You should see "✅ Firebase initialized successfully" in the debug console

## Current Configuration

- **Bundle ID:** `com.example.pretiumMock`
- **Firebase Project:** `truepay-72060`
- **File Location:** `ios/Runner/GoogleService-Info.plist`
- **File Status:** ✅ Exists in filesystem, ❌ Not in Xcode project

