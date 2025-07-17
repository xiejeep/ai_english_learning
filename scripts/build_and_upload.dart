#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

void main() async {
  print('开始构建和上传流程...');

  // 步骤1: 执行 flutter build apk --release
  await buildApk();

  // 步骤2: 上传到蒲公英
  await uploadToPgyer();
}

/// 执行 Flutter APK 构建
Future<void> buildApk() async {
  print('\n=== 开始构建 APK ===');

  final result = await Process.run('flutter', [
    'build',
    'apk',
    '--release',
  ], workingDirectory: Directory.current.path);

  if (result.exitCode == 0) {
    print('✅ APK 构建成功');
    print(result.stdout);
  } else {
    print('❌ APK 构建失败');
    print('错误信息: ${result.stderr}');
    exit(1);
  }
}

/// 上传到蒲公英平台
Future<void> uploadToPgyer() async {
  print('\n=== 开始上传到蒲公英 ===');

  const apiKey = 'fe023acc330937d01c78d4303bfaeb94';
  const baseUrl = 'https://api.pgyer.com/apiv2';

  // APK 文件路径
  final apkPath = path.join(
    Directory.current.path,
    'build',
    'app',
    'outputs',
    'flutter-apk',
    'app-release.apk',
  );

  final apkFile = File(apkPath);
  if (!apkFile.existsSync()) {
    print('❌ APK 文件不存在: $apkPath');
    exit(1);
  }

  print('📱 找到 APK 文件: $apkPath');
  print(
    '📦 文件大小: ${(apkFile.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
  );

  try {
    // 步骤1: 获取上传凭证
    final tokenResponse = await getCOSToken(apiKey);
    if (tokenResponse == null) {
      print('❌ 获取上传凭证失败');
      exit(1);
    }

    print('✅ 获取上传凭证成功');

    // 步骤2: 上传文件
    final uploadSuccess = await uploadFile(tokenResponse, apkFile);
    if (!uploadSuccess) {
      print('❌ 文件上传失败');
      exit(1);
    }

    print('✅ 文件上传成功');

    // 步骤3: 检查发布状态
    await checkBuildStatus(apiKey, tokenResponse['key']);
  } catch (e) {
    print('❌ 上传过程中发生错误: $e');
    exit(1);
  }
}

/// 获取上传凭证
Future<Map<String, dynamic>?> getCOSToken(String apiKey) async {
  print('🔑 正在获取上传凭证...');

  final response = await http.post(
    Uri.parse('https://api.pgyer.com/apiv2/app/getCOSToken'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {
      '_api_key': apiKey,
      'buildType': 'android',
      'buildInstallType': '1', // 公开安装
      'buildDescription': 'AI English Learning App - 自动构建上传',
      'buildUpdateDescription': '通过自动化脚本构建和上传的版本',
    },
  );

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['code'] == 0) {
      return data['data'];
    } else {
      print('❌ API 错误: ${data['message']}');
      return null;
    }
  } else {
    print('❌ HTTP 错误: ${response.statusCode}');
    return null;
  }
}

/// 上传文件到云存储
Future<bool> uploadFile(Map<String, dynamic> tokenData, File apkFile) async {
  print('📤 正在上传文件...');

  final endpoint = tokenData['endpoint'];
  final params = tokenData['params'];

  final request = http.MultipartRequest('POST', Uri.parse(endpoint));

  // 添加必需的参数
  request.fields['key'] = params['key'];
  request.fields['signature'] = params['signature'];
  request.fields['x-cos-security-token'] = params['x-cos-security-token'];
  request.fields['x-cos-meta-file-name'] = path.basename(apkFile.path);

  // 添加文件
  request.files.add(
    await http.MultipartFile.fromPath(
      'file',
      apkFile.path,
      filename: path.basename(apkFile.path),
    ),
  );

  final response = await request.send();

  if (response.statusCode == 204) {
    return true;
  } else {
    print('❌ 上传失败，状态码: ${response.statusCode}');
    final responseBody = await response.stream.bytesToString();
    print('响应内容: $responseBody');
    return false;
  }
}

/// 检查构建状态
Future<void> checkBuildStatus(String apiKey, String buildKey) async {
  print('🔍 正在检查发布状态...');

  int attempts = 0;
  const maxAttempts = 30; // 最多检查30次，每次间隔10秒

  while (attempts < maxAttempts) {
    await Future.delayed(const Duration(seconds: 10));
    attempts++;

    final response = await http.get(
      Uri.parse(
        'https://api.pgyer.com/apiv2/app/buildInfo?_api_key=$apiKey&buildKey=$buildKey',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['code'] == 0) {
        final buildInfo = data['data'];
        print('✅ 应用发布成功!');
        print('📱 应用名称: ${buildInfo['buildName']}');
        print('🔢 版本号: ${buildInfo['buildVersion']}');
        final fileSize = int.parse(buildInfo['buildFileSize'].toString());
        print('📏 文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        print(
          '🔗 下载链接: https://www.pgyer.com/${buildInfo['buildShortcutUrl']}',
        );
        return;
      } else if (data['code'] == 1247) {
        print('⏳ 应用正在发布中... ($attempts/$maxAttempts)');
        continue;
      } else {
        print('❌ 检查状态失败: ${data['message']}');
        return;
      }
    } else {
      print('❌ HTTP 错误: ${response.statusCode}');
      return;
    }
  }

  print('⚠️ 检查超时，请手动访问蒲公英后台查看发布状态');
}
