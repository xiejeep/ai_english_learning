# Dify 代理服务 API 文档

## 1. 认证相关 API

### 1.1 发送验证码（注册用）
- **路径**: `/api/auth/send-code`
- **方法**: `POST`
- **说明**: 仅向未注册的邮箱发送注册验证码
- **请求体**:
```json
{
  "email": "string" // 邮箱地址
}
```
- **成功响应**:
```json
{
  "message": "验证码已发送到您的邮箱"
}
```
- **错误响应**:
```json
{
  "statusCode": 409,
  "message": "该邮箱已注册，请直接登录或使用密码重置功能",
  "error": "Conflict"
}
```

### 1.2 用户注册
- **路径**: `/api/auth/register`
- **方法**: `POST`
- **请求体**:
```json
{
  "email": "string",    // 邮箱地址
  "password": "string", // 密码（至少8位，必须包含大写字母、小写字母和数字）
  "username": "string", // 用户名
  "code": "string"      // 6位验证码
}
```
- **响应**:
```json
{
  "access_token": "string", // JWT token
  "user": {
    "id": "string",
    "email": "string",
    "username": "string"
  }
}
```

### 1.3 用户登录
- **路径**: `/api/auth/login`
- **方法**: `POST`
- **请求体**:
```json
{
  "email": "string",    // 邮箱地址
  "password": "string",  // 密码（至少8位，必须包含大写字母、小写字母和数字）
  "captchaSessionId": "string", // 验证码会话ID（多次登录失败后必填）
  "captchaCode": "string"       // 图形验证码（多次登录失败后必填）
}
```
- **响应**:
```json
{
  "access_token": "string", // JWT token
  "user": {
    "id": "string",
    "email": "string",
    "username": "string"
  }
}
```
- **错误响应**:
```json
{
  "statusCode": 401,
  "message": "邮箱或密码错误"
}
```
或
```json
{
  "statusCode": 400,
  "message": "需要输入图形验证码"
}
```
或
```json
{
  "statusCode": 401,
  "message": "账户已被锁定，请在 15 分钟后重试"
}
```

### 1.4 发送密码重置验证码
- **路径**: `/api/auth/send-reset-code`
- **方法**: `POST`
- **说明**: 仅向已注册的邮箱发送密码重置验证码
- **请求体**:
```json
{
  "email": "string" // 邮箱地址
}
```
- **成功响应**:
```json
{
  "message": "验证码已发送到您的邮箱"
}
```
- **错误响应**:
```json
{
  "statusCode": 400,
  "message": "该邮箱未注册",
  "error": "Bad Request"
}
```

### 1.5 重置密码
- **路径**: `/api/auth/reset-password`
- **方法**: `POST`
- **请求体**:
```json
{
  "email": "string",       // 邮箱地址
  "code": "string",        // 6位验证码
  "newPassword": "string"  // 新密码（至少8位，必须包含大写字母、小写字母和数字）
}
```
- **成功响应**:
```json
{
  "message": "密码重置成功"
}
```
- **错误响应**:
```json
{
  "statusCode": 400,
  "message": "验证码无效或已过期",
  "error": "Bad Request"
}
```
或
```json
{
  "statusCode": 400,
  "message": "该邮箱未注册",
  "error": "Bad Request"
}
```

## 2. 积分相关 API

### 2.1 查询积分余额
- **路径**: `/api/credits/balance`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "credits": number // 积分余额
}
```

### 2.2 查询积分历史
- **路径**: `/api/credits/history`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **查询参数**:
  - `page`: number (默认: 1)
  - `limit`: number (默认: 20)
- **响应**:
```json
{
  "items": [
    {
      "id": "string",
      "amount": number,
      "type": "string",
      "reason": "string",
      "createdAt": "string"
    }
  ],
  "total": number,
  "page": number,
  "limit": number
}
```

## 3. 签到相关 API

### 3.1 每日签到
- **路径**: `/api/checkin`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "success": boolean,
  "creditEarned": number,
  "consecutiveDays": number,
  "totalCredits": number,
  "message": "string"
}
```

### 3.2 获取签到状态
- **路径**: `/api/checkin/status`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "hasCheckedIn": boolean,
  "consecutiveDays": number,
  "lastCheckinDate": "string"
}
```

### 3.3 获取签到历史
- **路径**: `/api/checkin/history`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **查询参数**:
  - `page`: number (默认: 1)
  - `limit`: number (默认: 20)
- **响应**:
```json
{
  "items": [
    {
      "id": "string",
      "checkinDate": "string",
      "creditEarned": number,
      "consecutiveDays": number
    }
  ],
  "total": number,
  "page": number,
  "limit": number
}
```

## 4. Dify 代理 API

### 4.1 发送聊天消息
- **路径**: `/api/dify/chat-messages`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "inputs": object,
  "query": "string",
  "response_mode": "streaming" | "blocking",
  "conversation_id": "string"
}
```
- **响应**:
```json
{
  "answer": "string",
  "conversation_id": "string",
  "task_id": "string"
}
```

### 4.2 发送完成消息
- **路径**: `/api/dify/completion-messages`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "inputs": object,
  "query": "string",
  "response_mode": "streaming" | "blocking"
}
```
- **响应**:
```json
{
  "answer": "string",
  "task_id": "string"
}
```

### 4.3 运行工作流
- **路径**: `/api/dify/workflows/run`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "inputs": object,
  "response_mode": "streaming" | "blocking"
}
```
- **响应**:
```json
{
  "workflow_run_id": "string",
  "task_id": "string",
  "data": object
}
```

### 4.4 音频转文本
- **路径**: `/api/dify/audio-to-text`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: multipart/form-data`
- **请求体**:
```json
{
  "file": "File"
}
```
- **响应**:
```json
{
  "text": "string"
}
```

### 4.5 文本转语音
- **路径**: `/api/dify/text-to-audio`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "text": "string"
}
```
- **响应**:
```json
{
  "audio_url": "string" // 或 "audio_base64": "string"
}
```

### 4.6 通用代理请求
- **路径**: `/api/dify/proxy`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "endpoint": "string",
  "data": object,
  "headers": object
}
```
- **响应**:
```json
{
  "data": object
}
```

### 4.7 获取API使用统计
- **路径**: `/api/dify/usage-stats`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **查询参数**:
  - `days`: number (默认: 7)
- **响应**:
```json
{
  "totalRequests": number,
  "totalCreditsUsed": number,
  "dailyStats": [
    {
      "date": "string",
      "requests": number,
      "creditsUsed": number
    }
  ]
}
```

### 4.8 获取建议问题
- **路径**: `/api/dify/messages/{messageId}/suggested`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "data": [
    {
      "question": "string"
    }
  ]
}
```

### 4.9 获取会话列表
- **路径**: `/api/dify/conversations`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "data": [
    {
      "id": "string",
      "name": "string",
      "created_at": "string"
    }
  ]
}
```

### 4.10 获取会话消息
- **路径**: `/api/dify/conversations/{conversationId}/messages`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **查询参数**:
  - `first_id`: string (可选) - 指定起始消息ID，用于cursor分页
  - `limit`: number (默认: 20) - 每页数量，最大100
- **响应**:
```json
{
  "limit": 20,
  "has_more": true,
  "data": [
    {
      "id": "string",
      "conversation_id": "string",
      "inputs": {},
      "query": "string",
      "answer": "string",
      "message_files": [
        {
          "id": "string",
          "type": "string",
          "url": "string",
          "belongs_to": "user"
        }
      ],
      "feedback": {
        "rating": "like"
      },
      "retriever_resources": [
        {
          "position": 123,
          "dataset_id": "string",
          "dataset_name": "string",
          "document_id": "string",
          "document_name": "string",
          "segment_id": "string",
          "score": 123,
          "content": "string"
        }
      ],
      "created_at": 123
    }
  ]
}
```

**分页说明**:
- **Cursor分页**: 使用 `first_id` 参数指定起始消息ID进行分页
- Dify API 仅支持基于 `first_id` 的游标分页，不支持传统的 `page` 参数分页
- 响应中的 `has_more` 字段表示是否还有更多数据
- 如果不传 `first_id`，则返回最新的消息

### 4.11 删除会话
- **路径**: `/api/dify/conversations/{conversationId}`
- **方法**: `DELETE`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "success": boolean,
  "message": "string"
}
```

### 4.12 重命名会话
- **路径**: `/api/dify/conversations/{conversationId}/name`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "name": "string"
}
```
- **响应**:
```json
{
  "success": boolean,
  "message": "string"
}
```

### 4.13 获取会话变量
- **路径**: `/api/dify/conversations/{conversationId}/variables`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "variables": object
}
```

### 4.14 消息反馈
- **路径**: `/api/dify/messages/{messageId}/feedbacks`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- **请求体**:
```json
{
  "rating": "like" | "dislike"
}
```
- **响应**:
```json
{
  "success": boolean,
  "message": "string"
}
```

### 4.15 获取消息反馈统计
- **路径**: `/api/dify/messages/{messageId}/feedback-stats`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "likes": number,
  "dislikes": number
}
```

### 4.16 停止响应
- **路径**: `/api/dify/chat-messages/{taskId}/stop`
- **方法**: `POST`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "success": boolean,
  "message": "string"
}
```

### 4.17 获取应用 Meta 信息
- **路径**: `/api/dify/meta`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "app": {
    "id": "string",
    "name": "string",
    "description": "string"
  }
}
```

### 4.18 获取应用参数
- **路径**: `/api/dify/parameters`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "parameters": object
}
```

## 5. 用户相关 API

### 5.1 获取用户资料
- **路径**: `/api/user/profile`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "id": "string",
  "email": "string",
  "username": "string",
  "createdAt": "string",
  "updatedAt": "string"
}
```

### 5.2 获取用户统计
- **路径**: `/api/user/stats`
- **方法**: `GET`
- **请求头**: 
  - `Authorization: Bearer <token>`
- **响应**:
```json
{
  "totalCredits": number,
  "totalApiCalls": number,
  "totalCheckins": number,
  "consecutiveCheckins": number
}
```

## 6. 健康检查 API

### 6.1 服务状态检查
- **路径**: `/api/health`
- **方法**: `GET`
- **响应**:
```json
{
  "success": boolean,
  "status": "ok",
  "timestamp": "string",
  "uptime": number,
  "environment": "string"
}
```

### 6.2 根路径
- **路径**: `/`
- **方法**: `GET`
- **响应**:
```json
"Hello World!"
```

### 检查登录状态

**接口地址：** `GET /api/auth/login-status`

**请求参数：**
```
GET /api/auth/login-status?email=user@example.com
```

**参数说明：**
- `email`: 用户邮箱（可选，用于检查特定邮箱的状态）

**成功响应：**
```json
{
  "requiresCaptcha": false,
  "isLocked": false,
  "failureCount": 0,
  "remainingLockTime": 0
}
```

**响应字段说明：**
- `requiresCaptcha`: 是否需要图形验证码
- `isLocked`: 账户是否被锁定
- `failureCount`: 登录失败次数
- `remainingLockTime`: 剩余锁定时间（秒）

## 图形验证码相关接口

### 生成图形验证码

**接口地址：** `GET /api/captcha/generate`

**成功响应：**
```json
{
  "sessionId": "captcha_session_id",
  "captcha": "<svg>...</svg>"
}
```

**响应字段说明：**
- `sessionId`: 验证码会话ID，用于后续验证
- `captcha`: SVG格式的验证码图片

### 验证图形验证码

**接口地址：** `POST /api/captcha/verify`

**请求参数：**
```json
{
  "sessionId": "captcha_session_id",
  "code": "ABCD"
}
```

**成功响应：**
```json
{
  "message": "验证码验证成功",
  "valid": true
}
```

**错误响应：**
```json
{
  "message": "验证码无效或已过期",
  "valid": false
}
```

## 注意事项

### 密码安全策略

1. **强密码要求**：
   - 密码长度至少8位
   - 必须包含至少一个大写字母
   - 必须包含至少一个小写字母
   - 必须包含至少一个数字
   - 最大长度50位

2. **登录安全机制**：
   - 连续3次登录失败后需要输入图形验证码
   - 连续3次登录失败后账户被锁定15分钟
   - 锁定期间无法登录，即使密码正确
   - 成功登录后清除失败记录

### 验证码安全机制

1. **注册验证码发送条件**：
   - 仅当邮箱未注册时才发送注册验证码
   - 如果邮箱已注册，返回错误提示

2. **密码重置验证码发送条件**：
   - 仅当邮箱已注册时才发送密码重置验证码
   - 如果邮箱未注册，返回错误提示

3. **验证码有效期**：
   - 邮箱验证码有效期为5分钟
   - 图形验证码有效期为10分钟
   - 验证码使用后立即失效

4. **验证码失效机制**：
   - 验证码一旦使用成功，立即标记为已使用
   - 过期的验证码自动失效
   - 每个邮箱同一时间只能有一个有效的验证码

5. **图形验证码机制**：
   - 基于IP地址和邮箱地址跟踪登录失败次数
   - 失败次数达到阈值时强制要求图形验证码
   - 验证码为4位字符，包含数字和字母
   - 验证码区分大小写

这些机制有效防止了：
- 邮件轰炸攻击
- 暴力破解攻击
- 信息泄露（通过验证码发送状态推测邮箱是否已注册）
- 验证码重复使用
- 提升用户体验（明确的错误提示和安全状态查询）

### 通用规则

1. 所有需要认证的接口都需要在请求头中携带 `Authorization: Bearer <token>`
2. 所有请求和响应都使用 JSON 格式
3. 时间戳格式为 ISO 8601 标准
4. 分页接口默认每页 20 条数据
5. 错误响应格式统一为：
```json
{
  "success": false,
  "statusCode": number,
  "error": "string",
  "message": "string",
  "timestamp": "string",
  "path": "string"
}
```

可以使用账号 278245181@qq.com 密码123456Aa测试
