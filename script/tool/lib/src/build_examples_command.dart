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
