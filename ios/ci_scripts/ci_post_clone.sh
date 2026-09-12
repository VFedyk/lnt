#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

# Swift Package Manager must stay ENABLED. Plugins that ship a Package.swift are
# skipped as CocoaPods pods, and some (receive_sharing_intent 1.9+) no longer ship a
# podspec at all — disabling SPM leaves GeneratedPluginRegistrant.m importing a module
# nothing provides ("Module not found"). The SPM integration is committed in the
# Xcode project, so the plugins resolve from there.
flutter config --enable-swift-package-manager

# Install Flutter dependencies.
flutter pub get

# Install CocoaPods using Homebrew.
export HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
which pod || brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install --repo-update # run `pod install` in the `ios` directory.

exit 0
