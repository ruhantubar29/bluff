> **Vendored copy of pub.dev `firebase_auth` 6.7.0.** The only file that
> differs from upstream is `android/build.gradle`: the dead-branch legacy
> Kotlin Gradle Plugin apply (a no-op under this app's AGP 9 + built-in
> Kotlin, but flagged by Flutter's build-script text scan) was removed. Dart,
> iOS, macOS and example sources are untouched. Revert path: when pub.dev
> ships a KGP-free release, delete `packages/firebase_auth` and remove the
> `dependency_overrides` entry in the app's `pubspec.yaml`.

[<img src="https://raw.githubusercontent.com/firebase/flutterfire/main/.github/images/flutter_favorite.png" width="200" />](https://flutter.dev/docs/development/packages-and-plugins/favorites)

# Firebase Auth for Flutter
[![pub package](https://img.shields.io/pub/v/firebase_auth.svg)](https://pub.dev/packages/firebase_auth)

A Flutter plugin to use the [Firebase Authentication API](https://firebase.google.com/products/auth/).

To learn more about Firebase Auth, please visit the [Firebase website](https://firebase.google.com/products/auth)

## Getting Started

To get started with Firebase Auth for Flutter, please [see the documentation](https://firebase.google.com/docs/auth/flutter/start).

## Usage

To use this plugin, please visit the [Authentication Usage documentation](https://firebase.google.com/docs/auth/flutter/manage-users)

## Issues and feedback

Please file FlutterFire specific issues, bugs, or feature requests in our [issue tracker](https://github.com/firebase/flutterfire/issues/new).

Plugin issues that are not specific to FlutterFire can be filed in the [Flutter issue tracker](https://github.com/flutter/flutter/issues/new).

To contribute a change to this plugin,
please review our [contribution guide](https://github.com/firebase/flutterfire/blob/main/CONTRIBUTING.md)
and open a [pull request](https://github.com/firebase/flutterfire/pulls).
