#!/bin/bash

# ==============================================================================
#  该脚本用于设置root密码并启用SSH的root用户密码登录。
#  警告：从安全角度出发，强烈不建议在生产环境中启用root密码登录。
#         最佳实践是使用普通用户+sudo以及SSH密钥认证。
# ==============================================================================

# 检查脚本是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请使用sudo运行此脚本 (e.g., sudo ./your_script_name.sh)"
  exit 1
fi

# --- 步骤 1: 获取并确认新密码 ---
echo "请输入新的root密码："
read -s new_password
# -s 选项不会在读取后自动换行，手动添加一个空行以改善输出格式
echo "" 

echo "请再次输入新的root密码以确认："
read -s confirm_password
echo ""

# 检查两次输入的密码是否一致
if [ -z "$new_password" ] || [ "$new_password" != "$confirm_password" ]; then
    echo "错误：两次输入的密码不一致或密码为空。操作已取消。"
    exit 1
fi

# --- 步骤 2: 修改root密码 ---
echo "正在更改root密码..."
# 使用 chpasswd 替代 passwd管道，更安全
echo "root:$new_password" | chpasswd

if [ $? -eq 0 ]; then
    echo "Root密码已成功更改。"
else
    echo "错误：更改Root密码失败。"
    exit 1
fi

# --- 步骤 3: 修改SSH配置文件 ---
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

echo "正在修改SSH配置以启用root登录和密码认证..."

# 在修改前创建备份文件（例如 /etc/ssh/sshd_config.bak）
# 将多个sed表达式合并为一次调用，更高效
# 移除了脚本内部不必要的 sudo
sed -i.bak \
    -e 's/^#*[[:space:]]*PermitRootLogin.*/PermitRootLogin yes/' \
    -e 's/^#*[[:space:]]*PasswordAuthentication.*/PasswordAuthentication yes/' \
    "$SSHD_CONFIG_FILE"

# 检查配置是否已成功更改
if grep -q "^PermitRootLogin yes" "$SSHD_CONFIG_FILE" && grep -q "^PasswordAuthentication yes" "$SSHD_CONFIG_FILE"; then
    echo "SSH配置文件已成功修改。"
else
    echo "错误：修改SSH配置文件失败，请手动检查 $SSHD_CONFIG_FILE 文件。"
    echo "备份文件已创建于 ${SSHD_CONFIG_FILE}.bak"
    exit 1
fi

# --- 步骤 4: 重启SSH服务 ---
echo "正在重启SSH服务以应用更改..."
systemctl restart sshd

if [ $? -eq 0 ]; then
    echo "操作成功！SSH服务已重启，root登录和密码认证已启用。"
    echo "请务必妥善保管好您的root密码！"
else
    echo "错误：SSH服务重启失败。请使用 'systemctl status sshd' 或 'journalctl -xe' 检查系统日志。"
    exit 1
fi

exit 0