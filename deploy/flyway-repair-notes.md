# Flyway 生产环境修复手册

> **k2/k4 Items**: #2 (No fake "just rerun"), #5 (Dual-table merge), #10 (Full runbook), #12 (No auto-repair)

## 解锁顺序（生产环境）

```
freeze Restart → backup → inventory → merge → repair → Deploy → start app
```

---

## 场景 A: V3 失败 - MySQL 1050 "Table already exists"

### 背景

Deploy run 34622776776 失败：
- V2 成功（`success=1`）
- V3 失败，错误 `MySQL 1050: Table 'points_log' already exists`
- 原因：`points_logs` 和 `points_log` 两个表同时存在
- 同样风险：`task_items` / `tasks`

### 修复后的 V3 行为

新版 V3 使用三态逻辑：
1. **仅旧表存在** → RENAME（正常路径）
2. **仅新表存在** → noop（已迁移）
3. **双表存在** → 不 RENAME，执行 INSERT...WHERE NOT EXISTS 合并

### ⚠️ 重要：PK 冲突处理

当双表存在且有相同 ID 的记录时：
- **新表的行被保留**（JPA canonical 优先）
- 旧表的同 ID 行**不会被插入**
- 这是设计行为，因为新表是 JPA 使用的规范表

**验证步骤**（合并后）：
```sql
-- 检查是否有旧表独有的 ID（应该为 0）
SELECT COUNT(*) AS orphaned_in_old
FROM points_logs old
WHERE NOT EXISTS (SELECT 1 FROM points_log new WHERE new.id = old.id);

-- 如果 > 0，检查这些记录
SELECT * FROM points_logs old
WHERE NOT EXISTS (SELECT 1 FROM points_log new WHERE new.id = old.id)
LIMIT 10;
```

---

## 步骤 1：冻结重启

```bash
# 停止任何自动重启/部署
pkill -f "lucky-sign" || true
sleep 2

# 确认已停止
pgrep -f "lucky-sign" && echo "WARNING: Process still running"
```

---

## 步骤 2：备份

```bash
BACKUP_FILE="lucky_sign_backup_$(date +%Y%m%d_%H%M%S).sql"
mysqldump -u root -p lucky_sign > "/backup/${BACKUP_FILE}"

# 验证备份
ls -la "/backup/${BACKUP_FILE}"
mysql -u root -p -e "SELECT COUNT(*) FROM lucky_sign.users;"
```

---

## 步骤 3：库存检查

### 3.1 检查双表状态

```sql
SELECT TABLE_NAME, TABLE_ROWS, CREATE_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'lucky_sign'
  AND TABLE_NAME IN ('points_logs', 'points_log', 'task_items', 'tasks')
ORDER BY TABLE_NAME;
```

### 3.2 检查 flyway_schema_history

```sql
SELECT installed_rank, version, description, success, installed_on
FROM flyway_schema_history
ORDER BY installed_rank;
```

### 3.3 行数对比

```sql
-- 积分日志表
SELECT 'points_logs' AS tbl, COUNT(*) AS cnt FROM points_logs
UNION ALL
SELECT 'points_log', COUNT(*) FROM points_log;

-- 任务表
SELECT 'task_items' AS tbl, COUNT(*) AS cnt FROM task_items
UNION ALL
SELECT 'tasks', COUNT(*) FROM tasks;
```

---

## 步骤 4：修复 flyway_schema_history

### 删除失败的 V3 记录

```sql
-- 仅删除 success=0 的记录
DELETE FROM flyway_schema_history 
WHERE version = '3' AND success = 0;

-- 确认删除
SELECT * FROM flyway_schema_history WHERE version = '3';
```

---

## 步骤 5：部署并运行迁移

```bash
# 拉取最新代码
cd /path/to/backend
git pull origin main

# 构建
mvn clean package -DskipTests

# 上传 JAR
scp target/lucky-sign-*.jar server:/www/wwwroot/lucky-api/

# SSH 到服务器
ssh user@server

# 仅运行迁移（不启动应用）
cd /www/wwwroot/lucky-api
./deploy/start-backend.sh --migrate-only

# 检查迁移日志
cat flyway-migrate.log
```

---

## 步骤 6：验证并清理旧表

### 6.1 验证行数

```sql
-- 确认新表行数 >= 旧表行数
SELECT 
    'points' AS domain,
    (SELECT COUNT(*) FROM points_logs) AS old_rows,
    (SELECT COUNT(*) FROM points_log) AS new_rows;

SELECT 
    'tasks' AS domain,
    (SELECT COUNT(*) FROM task_items) AS old_rows,
    (SELECT COUNT(*) FROM tasks) AS new_rows;
```

### 6.2 备份并删除旧表

```sql
-- 可选：归档旧表
CREATE TABLE _archive_points_logs_final AS SELECT * FROM points_logs;
CREATE TABLE _archive_task_items_final AS SELECT * FROM task_items;

-- 确认后删除
DROP TABLE points_logs;
DROP TABLE task_items;
```

---

## 步骤 7：启动应用

```bash
./deploy/start-backend.sh

# 验证
curl -s http://127.0.0.1:8080/api/user/profile
# 应返回 401/403（正常，未登录）
```

---

## 场景 B: V4 失败 - VARCHAR 长度超限

### 错误示例

```
ERROR: email_logs.subject has data length 156 which exceeds target VARCHAR(128).
```

### 修复步骤

1. **检查超长数据**：
```sql
SELECT id, CHAR_LENGTH(subject) AS len, LEFT(subject, 50) AS preview
FROM email_logs
WHERE CHAR_LENGTH(subject) > 128
ORDER BY len DESC;
```

2. **截断数据**：
```sql
UPDATE email_logs 
SET subject = LEFT(subject, 128) 
WHERE CHAR_LENGTH(subject) > 128;
```

3. **删除失败记录**：
```sql
DELETE FROM flyway_schema_history WHERE version = '4' AND success = 0;
```

4. **重新运行迁移**：
```bash
./deploy/start-backend.sh --migrate-only
```

---

## 场景 C: V2 失败 - MySQL 语法错误

如果 V2 失败（MariaDB 语法在 MySQL 8 不兼容）：

1. 检查已添加的列：
```sql
SELECT COLUMN_NAME FROM information_schema.COLUMNS 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' 
AND COLUMN_NAME IN ('token_version', 'enabled');
```

2. 删除失败记录：
```sql
DELETE FROM flyway_schema_history WHERE version = '2' AND success = 0;
```

3. 重新部署（新版 V2 使用 information_schema 检查）

---

## CI/CD 集成指南（k2 #12）

### 不要自动修复

```yaml
# ❌ 错误做法
- run: flyway repair && flyway migrate

# ✓ 正确做法
- run: ./deploy/start-backend.sh --check-flyway
- run: ./deploy/start-backend.sh --migrate-only
```

### 检测失败迁移

```bash
# check-flyway 会在发现 success=0 时返回退出码 2
./deploy/start-backend.sh --check-flyway || {
  echo "ERROR: Failed migration detected. Manual intervention required."
  echo "See deploy/flyway-repair-notes.md"
  exit 1
}
```

---

## 数据归档策略

V3 会删除以下列（**不归档**，因为 JPA 实体已不使用）：

| 表 | 删除的列 | 说明 |
|----|----------|------|
| chat_messages | mentions | JSON → VARCHAR(mentioned_user_ids) |
| chat_messages | related_draw_id | 实体未使用 |
| feedbacks | contact, status | 实体未使用 |
| email_logs | template_name | 实体未使用 |

如果需要归档这些数据，在运行 V3 前手动执行：

```sql
-- 归档 mentions
CREATE TABLE _archive_chat_mentions AS 
SELECT id, mentions FROM chat_messages WHERE mentions IS NOT NULL;

-- 归档 feedbacks 元数据
CREATE TABLE _archive_feedbacks_meta AS 
SELECT id, contact, status FROM feedbacks;

-- 归档 email template names
CREATE TABLE _archive_email_templates AS 
SELECT id, template_name FROM email_logs WHERE template_name IS NOT NULL;
```

---

## 快速参考

### 状态检查命令

```bash
# 检查 Flyway 状态（失败则退出码 2）
./deploy/start-backend.sh --check-flyway

# 仅运行迁移（不启动应用）
./deploy/start-backend.sh --migrate-only

# 正常启动（含迁移）
./deploy/start-backend.sh
```

### SQL 快查

```sql
-- Flyway 状态
SELECT version, description, success FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;

-- 双表检查
SELECT TABLE_NAME FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('points_logs','points_log','task_items','tasks');

-- 失败迁移
SELECT * FROM flyway_schema_history WHERE success = 0;
```

### 紧急回滚

```bash
# 1. 停止应用
pkill -f "lucky-sign"

# 2. 恢复数据库
mysql -u root -p lucky_sign < /backup/lucky_sign_backup_YYYYMMDD_HHMMSS.sql

# 3. 回滚代码
git checkout <previous_commit>

# 4. 重建并启动
mvn clean package -DskipTests
./deploy/start-backend.sh
```

---

## 联系支持

如果遇到此手册未涵盖的情况：
1. **不要盲目尝试修复**
2. 保留当前数据库状态
3. 导出 `flyway_schema_history` 全表
4. 记录 `SHOW CREATE TABLE` 输出
5. 联系 DBA 或开发团队
