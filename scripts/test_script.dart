#!/usr/bin/env dart
// 测试脚本 - 验证依赖和基本功能

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

void main() async {
  print('🧪 测试脚本依赖和基本功能...');

  // 测试 1: 检查依赖包
  print('\n=== 测试 1: 检查依赖包 ===');
  try {
    print('✅ dart:io - 可用');
    print('✅ dart:convert - 可用');
    print('✅ package:http - 可用');
    print('✅ package:path - 可用');
  } catch (e) {
    print('❌ 依赖包检查失败: $e');
    exit(1);
  }

  // 测试 2: 检查 Flutter 命令
  print('\n=== 测试 2: 检查 Flutter 环境 ===');
  try {
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode == 0) {
      print('✅ Flutter 命令可用');
      final version = result.stdout.toString().split('\n')[0];
      print('📱 $version');
    } else {
      print('❌ Flutter 命令不可用');
    }
  } catch (e) {
    print('❌ Flutter 检查失败: $e');
  }

  // 测试 3: 检查项目结构
  print('\n=== 测试 3: 检查项目结构 ===');
  final currentDir = Directory.current.path;
  print('📁 当前目录: $currentDir');

  final pubspecFile = File(path.join(currentDir, 'pubspec.yaml'));
  if (pubspecFile.existsSync()) {
    print('✅ pubspec.yaml 存在');
  } else {
    print('❌ pubspec.yaml 不存在');
  }

  final androidDir = Directory(path.join(currentDir, 'android'));
  if (androidDir.existsSync()) {
    print('✅ android 目录存在');
  } else {
    print('❌ android 目录不存在');
  }

  // 测试 4: 检查网络连接
  print('\n=== 测试 4: 检查网络连接 ===');
  try {
    final response = await http
        .get(Uri.parse('https://api.pgyer.com/apiv2/app/getCOSToken'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 400) {
      print('✅ 蒲公英 API 可访问');
    } else {
      print('⚠️ 蒲公英 API 响应异常: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ 网络连接测试失败: $e');
  }

  // 测试 5: JSON 处理
  print('\n=== 测试 5: JSON 处理 ===');
  try {
    final testData = {
      'code': 0,
      'message': 'success',
      'data': {
        'key': 'test-key',
        'endpoint': 'https://example.com',
        'params': {'signature': 'test-signature'},
      },
    };

    final jsonString = json.encode(testData);
    final decoded = json.decode(jsonString);

    if (decoded['code'] == 0) {
      print('✅ JSON 编码/解码正常');
    } else {
      print('❌ JSON 处理异常');
    }
  } catch (e) {
    print('❌ JSON 处理测试失败: $e');
  }

  print('\n🎉 测试完成!');
  print('\n💡 如果所有测试都通过，可以运行实际的构建脚本:');
  print('   ./scripts/build_and_upload.sh');
  print('   或');
  print('   dart scripts/build_and_upload.dart');
}
