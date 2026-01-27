#!/bin/bash

# 运行 Flutter Web 应用并保存日志
# 日志文件: logs/app.log

cd "$(dirname "$0")/.."

# 确保 logs 目录存在
mkdir -p logs

# 生成带时间戳的日志文件名
LOG_FILE="logs/app_$(date +%Y%m%d_%H%M%S).log"

echo "启动应用，日志将保存到: $LOG_FILE"
echo "按 Ctrl+C 停止应用"
echo "-----------------------------------"

# 运行 Flutter 并同时输出到终端和日志文件
#flutter run -d chrome 2>&1 | tee "$LOG_FILE"
NO_PROXY=localhost,127.0.0.1 flutter run -d chrome 2>&1 | tee "$LOG_FILE"
