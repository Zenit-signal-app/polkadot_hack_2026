import 'dart:io';

void main() {
  final configFile = File('lib/core/ads/admob_config.dart');
  final androidStringsFile =
      File('android/app/src/main/res/values/strings.xml');
  final iosInfoPlistFile = File('ios/Runner/Info.plist');

  if (!configFile.existsSync()) {
    stderr.writeln('Missing file: ${configFile.path}');
    exitCode = 1;
    return;
  }

  final configContent = configFile.readAsStringSync();
  final androidAppId = _extractConfigValue(configContent, 'androidAppId');
  final iosAppId = _extractConfigValue(configContent, 'iosAppId');

  _syncAndroidStrings(androidStringsFile, androidAppId);
  _syncIosInfoPlist(iosInfoPlistFile, iosAppId);

  stdout.writeln('Synced AdMob IDs from lib/core/ads/admob_config.dart');
  stdout.writeln('Android App ID: $androidAppId');
  stdout.writeln('iOS App ID: $iosAppId');
}

String _extractConfigValue(String source, String fieldName) {
  final regex = RegExp(
    "static\\s+const\\s+String\\s+$fieldName\\s*=\\s*'([^']+)';",
    multiLine: true,
  );
  final match = regex.firstMatch(source);
  if (match == null || match.groupCount < 1) {
    throw StateError('Cannot find "$fieldName" in admob_config.dart');
  }
  return match.group(1)!;
}

void _syncAndroidStrings(File file, String androidAppId) {
  if (!file.existsSync()) {
    throw StateError('Missing file: ${file.path}');
  }

  final content = file.readAsStringSync();
  final regex = RegExp(
    r'(<string\s+name="admob_app_id">)([^<]*)(</string>)',
    multiLine: true,
  );

  if (!regex.hasMatch(content)) {
    throw StateError('Cannot find <string name="admob_app_id"> in ${file.path}');
  }

  final updated = content.replaceFirstMapped(regex, (match) {
    return '${match.group(1)}$androidAppId${match.group(3)}';
  });

  file.writeAsStringSync(updated);
}

void _syncIosInfoPlist(File file, String iosAppId) {
  if (!file.existsSync()) {
    throw StateError('Missing file: ${file.path}');
  }

  final content = file.readAsStringSync();
  final regex = RegExp(
    r'(<key>GADApplicationIdentifier</key>\s*<string>)([^<]*)(</string>)',
    multiLine: true,
  );

  if (!regex.hasMatch(content)) {
    throw StateError('Cannot find GADApplicationIdentifier in ${file.path}');
  }

  final updated = content.replaceFirstMapped(regex, (match) {
    return '${match.group(1)}$iosAppId${match.group(3)}';
  });

  file.writeAsStringSync(updated);
}
