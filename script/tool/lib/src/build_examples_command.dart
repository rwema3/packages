// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:yaml/yaml.dart';

import 'common/core.dart';
import 'common/output_utils.dart';
import 'common/package_looping_command.dart';
import 'common/plugin_utils.dart';
import 'common/repository_package.dart';

/// Key for APK.
const String _platformFlagApk = 'apk';

const String _pluginToolsConfigFileName = '.pluginToolsConfig.yaml';
const String _pluginToolsConfigBuildFlagsKey = 'buildFlags';
const String _pluginToolsConfigGlobalKey = 'global';

const String _pluginToolsConfigExample = '''
$_pluginToolsConfigBuildFlagsKey:
  $_pluginToolsConfigGlobalKey:
    - "--no-tree-shake-icons"
    - "--dart-define=buildmode=testing"
''';

const int _exitNoPlatformFlags = 3;
const int _exitInvalidPluginToolsConfig = 4;

// Flutter build types. These are the values passed to `flutter build <foo>`.
const String _flutterBuildTypeAndroid = 'apk';
const String _flutterBuildTypeIOS = 'ios';
const String _flutterBuildTypeLinux = 'linux';
const String _flutterBuildTypeMacOS = 'macos';
const String _flutterBuildTypeWeb = 'web';
const String _flutterBuildTypeWindows = 'windows';

const String _flutterBuildTypeAndroidAlias = 'android';

/// A command to build the example applications for packages.
class BuildExamplesCommand extends PackageLoopingCommand {
  /// Creates an instance of the build command.
  BuildExamplesCommand(
    super.packagesDir, {
    super.processRunner,
    super.platform,
  }) {
    argParser.addFlag(platformLinux);
    argParser.addFlag(platformMacOS);
    argParser.addFlag(platformWeb);
    argParser.addFlag(platformWindows);
    argParser.addFlag(platformIOS);
    argParser.addFlag(_platformFlagApk,
        aliases: const <String>[_flutterBuildTypeAndroidAlias]);
    argParser.addOption(
      kEnableExperiment,
      defaultsTo: '',
      help: 'Enables the given Dart SDK experiments.',
    );
  }

  // Maps the switch this command uses to identify a platform to information
  // about it.
  static final Map<String, _PlatformDetails> _platforms =
      <String, _PlatformDetails>{
    _platformFlagApk: const _PlatformDetails(
      'Android',
      pluginPlatform: platformAndroid,
      flutterBuildType: _flutterBuildTypeAndroid,
    ),
    platformIOS: const _PlatformDetails(
      'iOS',
      pluginPlatform: platformIOS,
      flutterBuildType: _flutterBuildTypeIOS,
      extraBuildFlags: <String>['--no-codesign'],
    ),
    platformLinux: const _PlatformDetails(
      'Linux',
      pluginPlatform: platformLinux,
      flutterBuildType: _flutterBuildTypeLinux,
    ),
    platformMacOS: const _PlatformDetails(
      'macOS',
      pluginPlatform: platformMacOS,
      flutterBuildType: _flutterBuildTypeMacOS,
    ),
    platformWeb: const _PlatformDetails(
      'web',
      pluginPlatform: platformWeb,
      flutterBuildType: _flutterBuildTypeWeb,
    ),
    platformWindows: const _PlatformDetails(
      'Windows',
      pluginPlatform: platformWindows,
      flutterBuildType: _flutterBuildTypeWindows,
    ),
  };

  @override
  final String name = 'build-examples';

  @override
  final String description =
      'Builds all example apps (IPA for iOS and APK for Android).\n\n'
      'This command requires "flutter" to be in your path.\n\n'
      'A $_pluginToolsConfigFileName file can be placed in an example app '
      'directory to specify additional build arguments. It should be a YAML '
      'file with a top-level map containing a single key '
      '"$_pluginToolsConfigBuildFlagsKey" containing a map containing a '
      'single key "$_pluginToolsConfigGlobalKey" containing a list of build '
      'arguments.';
