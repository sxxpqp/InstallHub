#!/bin/bash
# 检查是否为 root 用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "请使用 root 用户执行此脚本。"
        exit 1
    fi
}
check_command_success() {
    command="$1" # 获取命令参数
    echo "执行命令: $command"

    # 执行命令并捕获输出（包括标准错误）
    output=$($command 2>&1)

    # 判断命令是否成功
    if [ $? -eq 0 ]; then
        echo "$output"
        echo "$command 命令执行成功"
    else
        echo "$command 命令执行失败，错误信息如下："
        echo "$output"
    fi
}


is_command_available() {
    command="$1"
    if command -v "$command" >/dev/null 2>&1; then
        echo "$command 可用"
    else
        echo "$command 不可用"
    fi
}
# check_command_success "wget https://jd.com"

# is_command_available docker
