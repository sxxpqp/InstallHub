#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2317
source value.sh
source installhub.sh
check_root

install-docker-offline() {
    if [ "$(command -v docker)" ]; then
        echo "docker 已安装"
    else

        choose_docker_version
        install_docker
    fi
}
docker_run_helloworld() {
    if [ "$(command -v docker)" ]; then
        check_command_success "docker run hello-world"
    else
        echo "docker 没有安装或者没有启动"
    fi
}

function download_file() {
    # 下载文件函数

    local file_url="$1"
    local file_path="$2"

    if [ ! -f "$file_path" ]; then
        echo "Downloading $file_url ..."
        if [ "$(command -v curl)" ]; then
            curl -o "$file_path" "$file_url"
        fi
        if [ "$(command -v wget)" ]; then
            wget -O "$file_path" "$file_url"
        else
            echo "Failed to download $file_url"
            exit 1
        fi
    else
        echo "$file_path already exists, skipping download."
    fi
}
function list_versions() {
    # 列出可用的 Docker 版本
    echo "Available Docker versions:"
    ls "$DOCKER_DIR"
}

function choose_docker_version() {
    # 用户选择 Docker 版本
    list_versions
    read -p "Enter the Docker version you want to install (default: $DOCKER_VERSION): " user_version
    if [ -n "$user_version" ]; then
        DOCKER_VERSION="$user_version"
        DOCKER_File="docker-$DOCKER_VERSION.tgz"
    fi
    if [ ! -f "$DOCKER_DIR/$DOCKER_File" ]; then
        echo "Version file not found in the local directory. Attempting to download..."
        download_file "$DOWNLOAD_URL/$DOCKER_File" "$DOCKER_DIR/$DOCKER_File"
    fi
}
function install_docker() {
    # 检测是否已安装 Docker
    if command -v dockerd >/dev/null 2>&1; then
        echo "Docker is already installed. Skipping installation."
        return
    fi

    # 解压 Docker 包并安装
    echo "Installing Docker version $DOCKER_VERSION..."
    tar -xzf "$DOCKER_DIR/$DOCKER_File" -C /tmp/
    cp /tmp/docker/* "$INSTALL_DIR/"

    # 配置 Docker 服务文件
    echo "[*] Register Docker service..."
    cat >/etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

    # 赋予 systemd 文件可执行权限
    chmod a+x /etc/systemd/system/docker.service
    chmod a+x /usr/local/bin/dockerd

    # 创建并配置 Docker 配置文件
    echo "[*] Create Docker config and modify it..."
    mkdir -p /etc/docker
    cat >/etc/docker/daemon.json <<EOF
{
    "log-opts": {},
    "registry-mirrors": [
        "https://dockerhub.sxxpqp.top"
    ]
}
EOF

    # 重载 systemd 配置并启动 Docker 服务
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker

    if [ $? -eq 0 ]; then
        echo "Docker $DOCKER_VERSION installed and service started successfully."
    else
        echo "Docker installed, but service start failed."
    fi
    install_docker_compose
}
function install_docker_compose() {
    # 检查 Docker Compose 是否已安装
    local compose_file="$DOCKER_DIR/docker-compose-linux-x86_64"
    download_file "$DOWNLOAD_URL/docker-compose-linux-x86_64" "$compose_file"

    if [ -f ~/.docker/cli-plugins/docker-compose ]; then
        echo "Docker Compose is already installed. Skipping installation."
        return
    fi

    # 安装 Docker Compose 插件
    echo "Installing Docker Compose..."
    mkdir -p ~/.docker/cli-plugins/
    cp "$compose_file" ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose

    # 验证安装是否成功
    if [ $? -eq 0 ]; then
        echo "Docker Compose installed successfully."
    else
        echo "Failed to install Docker Compose."
    fi
}
function uninstall_docker() {
    # 卸载 Docker
    echo "Uninstalling Docker..."
    rm -f "$INSTALL_DIR/docker"*

    # 停止并禁用 Docker 服务
    systemctl stop docker
    systemctl disable docker
    rm -f /etc/systemd/system/docker.service
    systemctl daemon-reload

    # 删除 Docker 配置文件
    rm -rf /etc/docker

    # 卸载 Docker Compose
    echo "Uninstalling Docker Compose..."
    rm -f ~/.docker/cli-plugins/docker-compose

    echo "Docker and Docker Compose uninstalled successfully."
}

# 退出程序
exit_program_menu() {
    echo "退出程序..."
    exit 0
}

# 安装 Docker
install_docker_menu() {
    echo "-----------------"
    echo "进入 Docker 安装菜单:"
    echo "1: 安装 Docker CE"
    echo "2: 卸载 Docker"
    echo "3: 启动helloworld"
    echo "b: 返回主菜单"
    echo "q: 退出"
    echo "-----------------"
    read -p "请输入您的选择: " choice
    case "$choice" in
    1)
        echo "正在安装 Docker..."
        install-docker-offline
        ;;
    2)
        echo "正在卸载 Docker..."
        uninstall_docker
        ;;
    3)
        echo "启动helloworld"
        docker_run_helloworld
        ;;
    b) main_menu ;;
    q) exit_program_menu ;;
    *)
        echo "无效选择，请重新选择。"
        install_docker_menu
        ;;
    esac
    install_docker_menu
    echo
    echo
    echo
}
# 部署docker-compose服务应用
deploy_service_menu() {
    echo "-----------------"
    echo "进入部署docker-compose服务应用菜单:"
    echo "1: mysql安装||卸载"
    echo "2: redis安装||卸载"
    echo "3: nginx安装||卸载"
    echo "b: 返回主菜单"
    echo "q: 退出"
    echo "-----------------"
    read -p "请输入您的选择: " choice
    case "$choice" in
    1)
        echo "mysql安装||卸载..."
        mysql-docker-compose-deploy
        ;;
    2)
        echo "redis安装||卸载..."
        redis-docker-compose-deploy
        ;;
    3)
        echo "nginx安装||卸载"
        nginx-docker-compose-deploy
        ;;
    b) main_menu ;;
    q) exit_program_menu ;;
    *)
        echo "无效选择，请重新选择。"
        deploy_service_menu
        ;;
    esac
    deploy_service_menu
    echo
    echo
    echo
}

# 主菜单函数
main_menu() {
    echo "-----------------"
    echo "请选择您要执行的操作:"
    echo "1: 安装 Docker"
    echo "2: 部署docker-compose服务"
    echo "3: 安装驱动"
    echo "4: 安装其他工具"
    echo "q: 退出"
    echo "-----------------"
    read -p "请输入您的选择: " choice
    case "$choice" in
    1) install_docker_menu ;;
    2) deploy_service_menu ;;
    3) install_drivers_menu ;;
    4) install_other_tools_menu ;;
    q) exit_program_menu ;;
    *)
        echo "无效选择，请重新选择。"
        main_menu
        ;;
    esac
}
# 调用主菜单
main_menu
