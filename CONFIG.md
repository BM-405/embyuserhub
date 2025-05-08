# EmbyUserHub 配置文档 (v3.0.8)

## 配置优先级说明

EmbyUserHub配置的加载优先级如下：
1. 环境变量（优先级最高）
2. 配置文件config.py（次优先级）
3. 默认配置（优先级最低）

当Docker容器重启时，系统会优先使用配置文件中的设置，除非环境变量中显式设置了相应的值。

## 配置项详解

### 基础配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `ADMIN_USERNAME` | 管理员用户名 | admin | - |
| `ADMIN_PASSWORD` | 管理员密码(支持明文或SHA256) | - | - |
| `TOTP_ISSUER` | 两步验证发行方名称 | EmbyUserHub | - |
| `SYSTEM_VERSION` | 系统版本 | 3.0.8 | - |
| `USERNAME_PREFIX` | 卡密创建用户名前缀 | emby | - |
| `USERNAME_DIGITS` | 后缀数字长度 | 6 | - |

### 数据库配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `DATABASE` | SQLite数据库文件路径（相对于项目根目录） | 'data/database.db' | - |

### 日志配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `APP_LOG_FILE` | 应用日志文件路径 | "data/app.log" | - |
| `APP_LOG_MAX_SIZE` | 应用日志最大大小 (bytes) | 10485760 (10MB) | - |
| `APP_LOG_BACKUP_COUNT` | 应用日志备份数量 | 5 | - |
| `LOG_LEVEL` | 日志记录等级 (DEBUG, INFO, WARNING, ERROR) | 'INFO' | - |
| `LOG_RETENTION_DAYS` | 日志保留天数 | 7 | - |
| `ENABLE_OPERATION_LOG` | 是否记录详细操作日志 | False | - |

### Emby服务器配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `EMBY_SERVER` | Emby服务器地址 | '根据实际服务器地址' | - |
| `ADMIN_TOKEN` | 管理员API密钥（从Emby管理页面获取） | - | - |
| `TEMPLATE_USER_ID` | 模板用户ID（新用户将复制此用户的权限设置） | - | - |

### 通知配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `ENABLE_EXPIRE_NOTIFICATION` | 是否启用到期通知 | False | - |
| `ENABLE_RENEW_NOTIFICATION` | 是否启用续费通知 | False | - |
| `ENABLE_ACTIVATION_NOTIFICATION` | 是否启用卡密激活通知 | False | - |
| `BARK_URL` | Bark推送地址（可选，不使用则留空） | '' | - |
| `BARK_TIMEOUT` | Bark请求超时时间（秒） | 15 | - |
| `BARK_SHOW_SSL_WARNINGS` | 是否显示SSL警告 | False | - |
| `BARK_ALLOW_INSECURE` | 是否允许不安全的HTTPS请求 | False | - |

> **Bark URL格式说明**:
> - 旧版API格式：'https://api.day.app/yourkey/'
> - 新版API格式：'https://api.day.app/yourkey'

### 安全配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `ENABLE_2FA` | 是否启用两步验证 | False | - |
| `LOGIN_ATTEMPT_LIMIT` | 登录尝试限制次数 | 5 | - |
| `LOGIN_BLOCK_TIME` | 登录锁定时间（秒） | 1800 | - |
| `SECURITY_CODE` | 安全访问码（用于保护管理页面） | 'admin123' | - |
| `ENABLE_SECURITY_ACCESS` | 是否启用安全访问 | True | `ENABLE_SECURITY_ACCESS` |
| `FLASK_SECRET_KEY` | Flask会话加密密钥 | - | `FLASK_SECRET_KEY` |

### 有效期选项

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `VALIDITY_OPTIONS` | 可配置的会员有效期选项 | 见下表 | - |

默认有效期选项:
```python
{
    '1d': 1,      # 1天会员
    '1m': 30,     # 1个月会员
    '3m': 90,     # 3个月会员
    '6m': 180,    # 6个月会员
    '12m': 365    # 12个月会员
}
```

### 系统配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|----------------------------------|
| `CHECK_EXPIRE_INTERVAL` | 检查过期用户间隔（分钟） | 60 | - |
| `CLEAN_USED_CODES_DAYS` | 清理已使用卡密的天数 | 7 | - |
| `LICENSE_SERVER_URL` | 许可证服务器地址 | "https://license.mmdns.top" | - |

### 清理设置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|----------------------------------|
| `AUTO_DELETE_EXPIRED_USERS_DAYS` | 自动删除过期用户天数 | 7 | - |
| `ENABLE_AUTO_DELETE_EXPIRED_USERS` | 是否启用自动删除过期用户 | False | - |
| `AUTO_DELETE_EXPIRE_INTERVAL` | 自动删除过期用户间隔(分钟) | 60 | - |

### 时区配置

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `SHANGHAI_OFFSET` | 上海时区偏移(UTC+8) | timedelta(hours=8) | - |
| `TZ` | 容器时区 | 'Asia/Shanghai' | `TZ` |

### 定时任务模式

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `CRON_MODE` | 定时任务模式 (thread/daemon) | 'thread' | `CRON_MODE` |

### 性能优化选项

| 配置项 | 说明 | 默认值 | 环境变量 |
|-------|------|-------|---------|
| `DATABASE_TIMEOUT` | 数据库操作超时时间(秒) | 60 | - |
| `DATABASE_RETRY_COUNT` | 数据库重试次数 | 3 | - |
| `THREAD_POOL_SIZE` | 并行操作线程池大小 | 5 | - |

## 环境变量说明

以下是Docker环境中可用的环境变量：

| 环境变量 | 描述 | 默认值 | 优先级 |
|---------|------|-------|-------|
| `TZ` | 容器时区 | Asia/Shanghai | 高 |
| `FLASK_SECRET_KEY` | Flask会话加密密钥 | wsH2KMJKJIQdwnRueNflgLqNFK6qiRGY2K-DfTKNWXM | 高 |
| `ENABLE_SECURITY_ACCESS` | 是否启用安全访问 | True | 高 |
| `CRON_MODE` | 定时任务模式 | thread | 高 |
| `VERSION` | 系统版本 | - | 高 |

## Docker部署示例

### 使用docker run部署

```bash
docker run -d \
  --name embyuserhub \
  --restart always \
  -p 29045:29045 \
  -v "/opt/embyuserhub/data:/app/data" \
  -v "/opt/embyuserhub/config:/app/config" \
  -e TZ=Asia/Shanghai \
  -e FLASK_SECRET_KEY=wsH2KMJKJIQdwnRueNflgLqNFK6qiRGY2K-DfTKNWXM \
  -e ENABLE_SECURITY_ACCESS=True \
  -e CRON_MODE=thread \
  mmbao/embyuserhub:3.0.8
```

## 配置文件优先级说明

1. 如果同一配置项同时在环境变量和配置文件中设置，环境变量的值将覆盖配置文件中的值。
2. 当容器重启时，环境变量将被重新应用，可能会覆盖已修改的配置文件设置。
3. 为了持久化配置，推荐在config.py文件中设置配置项，仅将关键的安全参数（如FLASK_SECRET_KEY）设为环境变量。

## 注意事项
- 首次启动容器后，会自动创建配置文件模板，请根据实际需求进行修改。
- 修改配置文件后需要重启容器才能生效。
- 定时任务模式可以根据需要调整，thread模式适合大多数场景。
