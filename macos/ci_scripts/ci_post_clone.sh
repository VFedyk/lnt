#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for macOS platform.
flutter precache --macos

# Disable Swift Package Manager: device_info_plus 11.x ships Package.swift, which
# causes Flutter on macOS to skip it as a CocoaPods pod while GeneratedPluginRegistrant.m
# still imports it — resulting in "Module not found" at compile time.
flutter config --no-enable-swift-package-manager

# Install Flutter dependencies.
flutter pub get

# Install CocoaPods using Homebrew.
export HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install CocoaPods dependencies.
cd macos && pod install --repo-update

exit 0
