# Flutter APK 构建和蒲公英上传脚本

这个脚本可以自动执行 Flutter APK 构建并上传到蒲公英平台。

## 文件说明

- `build_and_upload.dart` - 主要的 Dart 脚本，包含构建和上传逻辑
- `build_and_upload.sh` - Shell 脚本包装器，方便执行
- `README.md` - 使用说明文档

## 使用方法

### 方法一：使用 Shell 脚本（推荐）

```bash
# 在项目根目录下执行
./scripts/build_and_upload.sh
```

### 方法二：直接运行 Dart 脚本

```bash
# 在项目根目录下执行
dart scripts/build_and_upload.dart
```

## 脚本功能

1. **自动构建 APK**
   - 执行 `flutter build apk --release` 命令
   - 检查构建是否成功

2. **上传到蒲公英**
   - 获取上传凭证
   - 上传 APK 文件到云存储
   - 检查发布状态
   - 显示下载链接

## 配置说明

脚本中已经配置了以下参数：

- **API Key**: `fe023acc330937d01c78d4303bfaeb94`
- **安装方式**: 公开安装
- **应用描述**: "AI English Learning App - 自动构建上传"
- **更新描述**: "通过自动化脚本构建和上传的版本"

## 输出示例

```
开始构建和上传流程...

=== 开始构建 APK ===
✅ APK 构建成功

=== 开始上传到蒲公英 ===
📱 找到 APK 文件: /path/to/app-release.apk
📦 文件大小: 25.6 MB
🔑 正在获取上传凭证...
✅ 获取上传凭证成功
📤 正在上传文件...
✅ 文件上传成功
🔍 正在检查发布状态...
✅ 应用发布成功!
📱 应用名称: AI English Learning
🔢 版本号: 1.0.0
📏 文件大小: 25.6 MB
🔗 下载链接: https://www.pgyer.com/xxxxx
```

## 注意事项

1. **环境要求**
   - 确保已安装 Flutter SDK
   - 确保已安装 Dart SDK
   - 确保项目依赖已安装（`flutter pub get`）

2. **网络要求**
   - 需要稳定的网络连接
   - 上传大文件可能需要较长时间

3. **权限要求**
   - Shell 脚本需要执行权限（已通过 `chmod +x` 设置）

4. **错误处理**
   - 如果构建失败，脚本会显示错误信息并退出
   - 如果上传失败，会显示详细的错误信息
   - 发布状态检查最多等待 5 分钟（30次检查，每次间隔10秒）

## 故障排除

### 构建失败
- 检查 Flutter 环境是否正确配置
- 确保项目依赖完整：`flutter pub get`
- 检查 Android SDK 配置

### 上传失败
- 检查网络连接
- 确认 API Key 是否正确
- 检查 APK 文件是否存在

### 发布状态检查超时
- 可以手动访问蒲公英后台查看发布状态
- 通常 1-2 分钟内会完成发布

## 自定义配置

如需修改配置，可以编辑 `build_and_upload.dart` 文件中的相关参数：

```dart
// 修改应用描述
'buildDescription': '你的应用描述',

// 修改更新说明
'buildUpdateDescription': '你的更新说明',

// 修改安装方式（1:公开安装，2:密码安装，3:邀请安装）
'buildInstallType': '1',
```