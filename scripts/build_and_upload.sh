#!/bin/bash

# Flutter APK 构建和蒲公英上传脚本
# 使用方法: ./scripts/build_and_upload.sh

set -e  # 遇到错误立即退出

echo "🚀 开始 Flutter APK 构建和蒲公英上传流程"
echo "======================================"

# 检查是否在项目根目录
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 错误: 请在 Flutter 项目根目录下运行此脚本"
    exit 1
fi

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: Flutter 未安装或不在 PATH 中"
    exit 1
fi

# 检查 Dart 是否安装
if ! command -v dart &> /dev/null; then
    echo "❌ 错误: Dart 未安装或不在 PATH 中"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# 运行 Dart 脚本
echo "📱 执行构建和上传脚本..."
dart scripts/build_and_upload.dart

echo ""
echo "🎉 构建和上传流程完成!"