# 🚀 Flutter APK 自动构建和上传指南

本项目已配置自动化脚本，可以一键构建 Flutter APK 并上传到蒲公英平台。

## 📋 快速开始

### 方法一：使用 Shell 脚本（推荐）

```bash
# 在项目根目录执行
./scripts/build_and_upload.sh
```

### 方法二：使用 Dart 脚本

```bash
# 在项目根目录执行
dart scripts/build_and_upload.dart
```

### 方法三：使用编译后的可执行文件

```bash
# 在项目根目录执行
./scripts/build_and_upload
```

## ✅ 环境检查

运行以下命令检查环境是否正确配置：

```bash
dart scripts/test_script.dart
```

## 📱 脚本功能

1. **自动构建 Release APK**
   - 执行 `flutter build apk --release`
   - 验证构建结果

2. **自动上传到蒲公英**
   - 获取上传凭证
   - 上传 APK 文件
   - 监控发布状态
   - 提供下载链接

## 🔧 配置信息

- **蒲公英 API Key**: `fe023acc330937d01c78d4303bfaeb94`
- **安装方式**: 公开安装
- **应用描述**: "AI English Learning App - 自动构建上传"

## 📁 相关文件

- `scripts/build_and_upload.dart` - 主脚本
- `scripts/build_and_upload.sh` - Shell 包装器
- `scripts/build_and_upload` - 编译后的可执行文件
- `scripts/test_script.dart` - 环境测试脚本
- `scripts/README.md` - 详细文档

## ⚠️ 注意事项

1. 确保在项目根目录下运行脚本
2. 确保网络连接稳定
3. 首次运行前执行 `flutter pub get`
4. 构建过程可能需要几分钟时间

## 🆘 故障排除

如果遇到问题，请查看 `scripts/README.md` 中的详细故障排除指南。