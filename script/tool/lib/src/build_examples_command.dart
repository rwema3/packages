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

  @override
  Future<void> initializeRun() async {
    final List<String> platformFlags = _platforms.keys.toList();
    platformFlags.sort();
    if (!platformFlags.any((String platform) => getBoolArg(platform))) {
      printError(
          'None of ${platformFlags.map((String platform) => '--$platform').join(', ')} '
          'were specified. At least one platform must be provided.');
      throw ToolExit(_exitNoPlatformFlags);
    }
  }

  @override
  Future<PackageResult> runForPackage(RepositoryPackage package) async {
    final List<String> errors = <String>[];

    final bool isPlugin = isFlutterPlugin(package);
    final Iterable<_PlatformDetails> requestedPlatforms = _platforms.entries
        .where(
            (MapEntry<String, _PlatformDetails> entry) => getBoolArg(entry.key))
        .map((MapEntry<String, _PlatformDetails> entry) => entry.value);

    // Platform support is checked at the package level for plugins; there is
    // no package-level platform information for non-plugin packages.
    final Set<_PlatformDetails> buildPlatforms = isPlugin
        ? requestedPlatforms
            .where((_PlatformDetails platform) =>
                pluginSupportsPlatform(platform.pluginPlatform, package))
            .toSet()
        : requestedPlatforms.toSet();

    String platformDisplayList(Iterable<_PlatformDetails> platforms) {
      return platforms.map((_PlatformDetails p) => p.label).join(', ');
    }

    if (buildPlatforms.isEmpty) {
      final String unsupported = requestedPlatforms.length == 1
          ? '${requestedPlatforms.first.label} is not supported'
          : 'None of [${platformDisplayList(requestedPlatforms)}] are supported';
      return PackageResult.skip('$unsupported by this plugin');
