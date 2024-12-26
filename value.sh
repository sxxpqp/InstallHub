#!/bin/bash
# shellcheck disable=SC2034
DOCKER_DIR="/opt"       # 本地 Docker 离线包目录路径
DOCKER_VERSION="27.3.1" # 默认 Docker 版本
DOCKER_File="docker-$DOCKER_VERSION.tgz"
INSTALL_DIR="/usr/local/bin"  # Docker 安装目录
DOCKER_ROOT="/var/lib/docker" # Docker 数据目录
#DOWNLOAD_URL="https://minio.sxxpqp.top/docker" # 下载 URL
DOWNLOAD_URL="https://chfs.sxxpqp.top:8443/chfs/shared/docker" # 下载 URL
