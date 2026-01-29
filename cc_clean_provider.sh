#!/bin/bash

DB_PATH="$HOME/.cc-switch/cc-switch.db"

# 检查 sqlite3 是否安装
if ! command -v sqlite3 &> /dev/null; then
    echo "错误: 未找到 sqlite3 命令，请先安装 sqlite3。"
    exit 1
fi

# 检查数据库文件是否存在
if [ ! -f "$DB_PATH" ]; then
    echo "错误: 找不到数据库文件 $DB_PATH"
    exit 1
fi

echo "=== CC-Switch Provider 清理工具 ==="
echo "数据库路径: $DB_PATH"

# 列出当前所有 Provider
echo -e "\n正在读取 Provider 列表..."
echo "---------------------------------------------------------------------"
printf "% -36s | % -10s | % -20s | %s\n" "ID" "App Type" "Name" "Current?"
echo "---------------------------------------------------------------------"

# 使用 sqlite3 查询并格式化输出 (分离每一行以便 bash 处理)
sqlite3 -separator '|' "$DB_PATH" "SELECT id, app_type, name, is_current FROM providers ORDER BY app_type;" | while IFS='|' read -r id app name current; do
    # 格式化 is_current 显示
    if [ "$current" -eq 1 ]; then
        curr_text="[ACTIVE]"
    else
        curr_text=""
    fi
    printf "% -36s | % -10s | % -20s | %s\n" "$id" "$app" "$name" "$curr_text"
done

echo "---------------------------------------------------------------------"

# 获取用户输入
echo -e "\n请输入您想要**删除**的 Provider ID (即第一列的内容):"
read -r PROVIDER_ID

if [ -z "$PROVIDER_ID" ]; then
    echo "未输入 ID，操作已取消。"
    exit 0
fi

# 再次确认
echo -e "\n⚠️  警告: 即将永久删除 Provider ID: '$PROVIDER_ID'"
read -p "确认执行删除操作吗? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "操作已取消。"
    exit 0
fi

# 创建备份
BACKUP_FILE="${DB_PATH}.bak_$(date +%Y%m%d_%H%M%S)"
echo -e "\n正在创建数据库备份..."
if cp "$DB_PATH" "$BACKUP_FILE"; then
    echo "✅ 备份已保存至: $BACKUP_FILE"
else
    echo "❌ 备份失败，终止操作。"
    exit 1
fi

# 执行删除操作
# 1. 删除关联的 endpoints
sqlite3 "$DB_PATH" "DELETE FROM provider_endpoints WHERE provider_id='$PROVIDER_ID';"
# 2. 删除 provider 本体
sqlite3 "$DB_PATH" "DELETE FROM providers WHERE id='$PROVIDER_ID';"

echo -e "\n✅ 清理操作完成！"
echo "请重启 cc-switch 以查看变更。"
