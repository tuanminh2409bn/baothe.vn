#!/bin/sh

# Fail this script if any subcommand fails.
set -e
# Print commands for better debugging in Xcode Cloud logs.
set -x

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# ==========================================================
# 1. Generate secrets (api_keys.dart) from Environment Variable
# ==========================================================
mkdir -p lib/src/constants
cat <<EOF > lib/src/constants/api_keys.dart
class ApiKeys {
  static const String geminiApiKey = '${GEMINI_API_KEY}';
}
EOF

# ==========================================================
# 2. Install Flutter & Dependencies
# ==========================================================
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS
flutter precache --ios

# Install Flutter dependencies.
flutter pub get

# Generate Xcode build configurations explicitly.
# This prevents missing variables like FLUTTER_BUILD_NAME during Xcode's build phase.
flutter build ios --release --config-only

# ==========================================================
# 3. Install CocoaPods
# ==========================================================
# Xcode Cloud pre-installs cocoapods, but we ensure it is up to date and functional.
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

# Install CocoaPods dependencies with repo update.
cd ios
pod install --repo-update

exit 0
