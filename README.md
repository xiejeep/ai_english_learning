# AI English Learning App 🤖📚

> Flutter AI英语学习应用 - 基于Dify API的智能英语学习助手

## 📋 项目概述

这是一个功能完整的AI英语学习移动应用，提供智能对话练习、语法纠错、翻译功能、积分系统和签到奖励等核心服务。

### 🎯 核心功能

#### MVP阶段（当前开发）
- ✅ **用户认证系统**：邮箱验证码注册/登录、JWT管理
- 🔄 **AI英语对话**：流式响应、语法纠错、翻译、学习建议
- 🔄 **文本转语音(TTS)**：自动播放AI回复、手动朗读功能
- 🔄 **积分系统**：积分查询、消费记录、余额展示  
- 🔄 **每日签到**：连续签到奖励机制
- 🔄 **基础个人中心**：用户信息、基础设置
- 🔄 **会话管理**：创建/删除会话

#### 后期开发计划 ⏳
- 高级会话功能（重命名、消息反馈、导出）
- 学习进度可视化和数据分析
- 个性化学习设置

## 🏗️ 技术架构

### 核心技术栈
- **框架**：Flutter 3.16+
- **状态管理**：Riverpod 2.4+
- **网络请求**：Dio 5.3+（支持流式响应）
- **本地存储**：get_storage 2.1+
- **音频播放**：audioplayers 5.0+
- **路由管理**：go_router 12.0+
- **图片缓存**：cached_network_image 3.3+

### 项目结构
```
lib/
├── core/                 # 核心模块
│   ├── network/         # 网络请求层
│   ├── storage/         # 本地存储
│   ├── utils/           # 工具类
│   └── constants/       # 常量定义
├── shared/              # 共享模块
│   ├── widgets/         # 通用组件
│   ├── models/          # 数据模型
│   └── providers/       # 全局状态
├── features/            # 功能模块
│   ├── auth/           # 认证模块
│   ├── chat/           # 聊天模块
│   ├── credits/        # 积分模块
│   └── checkin/        # 签到模块
└── main.dart           # 应用入口
```

### Clean Architecture分层
- **Presentation层**：UI组件、页面、状态管理
- **Domain层**：业务逻辑、用例、实体模型
- **Data层**：数据源、Repository实现、API调用

## 🎨 设计特色

### 色彩方案
- **主色调**：学习蓝 #4A6FFF、进步绿 #00C9A7、成就金 #FFB400
- **功能色**：成功 #00C9A7、错误 #FF3B30、警告 #FF9500、信息 #34AADC

### 关键UI特性
- **英语学习对话界面**：支持实时语法纠错、翻译显示、学习建议
- **智能交互**：发送/停止按钮动态切换、流式AI回复展示
- **语音功能**：聊天气泡手动朗读、自动播放设置
- **学习激励**：积分系统、签到奖励、学习进度可视化

## 🚀 开发进度

### ✅ 已完成（Week 1-2）
- [x] Flutter项目创建和基本配置
- [x] Clean Architecture项目结构搭建
- [x] 核心依赖包配置 (Riverpod, Dio, get_storage等)
- [x] 网络层封装 (DioClient + 拦截器)
- [x] 本地存储服务 (StorageService)
- [x] 应用常量配置 (AppConstants)
- [x] 基础数据模型 (UserModel, MessageModel)
- [x] 应用主入口和启动页面
- [x] Git仓库初始化

### 🔄 正在开发（Week 3-5）
- [ ] 用户认证模块开发
- [ ] AI对话界面实现
- [ ] 流式响应处理
- [ ] 消息状态管理

### ⏳ 计划开发（Week 6-10）
- [ ] 积分系统实现
- [ ] 签到功能开发
- [ ] TTS语音功能
- [ ] 个人中心页面
- [ ] 应用设置功能

## 📱 核心功能预览

### AI英语学习对话
```
用户: "I want to learn English good"
AI回复: 
  ✅ 正确表达: "I want to learn English well"
  💡 语法提示: "good"应该用"well"(副词修饰动词)
  🌐 中文翻译: "我想学好英语"
  🔊 [语音播放按钮]
```

### 积分和签到系统
- 每日签到：+10积分
- AI对话：+5积分
- 连续签到奖励：7天+20积分，30天+50积分

## 🛠️ 开发指南

### 环境要求
- Flutter SDK >= 3.16.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- iOS开发需要Xcode

### 安装运行
```bash
# 克隆项目
git clone <repository-url>
cd ai_english_learning

# 获取依赖
flutter pub get

# 运行项目
flutter run
```

### 代码规范
- 使用Flutter推荐的代码规范
- 遵循Clean Architecture原则
- 状态管理使用Riverpod
- 网络请求统一使用DioClient
- 本地存储统一使用StorageService

## 🔧 配置说明

### API配置
在 `lib/core/constants/app_constants.dart` 中配置：
```dart
static const String baseUrl = 'https://your-api-domain.com';
```

### 本地存储
- 用户token: `user_token`
- 用户信息: `user_info`
- 聊天记录: `conversations`
- 积分余额: `credits_balance`
- TTS设置: `tts_auto_play`

## 📈 项目里程碑

| 阶段 | 时间 | 关键交付物 | 状态 |
|------|------|------------|------|
| 基础架构 | Week 1-2 | 项目结构、核心服务 | ✅ 完成 |
| 认证模块 | Week 3 | 登录注册功能 | 🔄 进行中 |
| 对话功能 | Week 4-5 | AI对话界面 | ⏳ 计划中 |
| 积分系统 | Week 6-7 | 积分签到功能 | ⏳ 计划中 |
| 功能完善 | Week 8-10 | 测试优化 | ⏳ 计划中 |

## 📄 许可证

本项目采用 MIT 许可证

## 👥 贡献指南

欢迎提交Issue和PR来改进项目！

---

**项目状态**: 🚧 开发中  
**当前版本**: v1.0.0  
**最后更新**: 2024年
