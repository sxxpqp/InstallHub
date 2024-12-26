#!/bin/bash
# shellcheck disable=SC1091
# shellcheck disable=SC2317
# shellcheck disable=SC2154
#source value.sh
#source installhub.sh
DOCKER_DIR="/opt"       # 本地 Docker 离线包目录路径
DOCKER_VERSION="27.3.1" # 默认 Docker 版本
DOCKER_File="docker-$DOCKER_VERSION.tgz"
INSTALL_DIR="/usr/local/bin" # Docker 安装目录
#DOCKER_ROOT="/var/lib/docker" # Docker 数据目录
#DOWNLOAD_URL="https://minio.sxxpqp.top/docker" # 下载 URL
DOWNLOAD_URL="https://chfs.sxxpqp.top:8443/chfs/shared/docker" # 下载 URL
# 下载固件文件的 URL
FIRMWARE_URL="https://chfs.sxxpqp.top:8443/chfs/shared/dirver/linux-firmware-20241017.tar.gz"
FIRMWARE_FILE="linux-firmware-20241017.tar.gz"
DOWNLOAD_DIR="/tmp/linux-firmware"

check_architecture() {
    arch=$(uname -m)

    case "$arch" in
    x86_64)
        echo "系统架构: 64 位 AMD (x86_64)"
        DOWNLOAD_URL="https://chfs.sxxpqp.top:8443/chfs/shared/docker"
        ;;
    aarch64)
        echo "系统架构: 64 位 ARM (aarch64)"
        DOWNLOAD_URL="https://chfs.sxxpqp.top:8443/chfs/shared/docker/aarch64"
        ;;
    armv7l)
        echo "系统架构: 32 位 ARM (armv7l)"
        ;;
    *)
        echo "不支持的系统架构: $arch, 只支持 ARM 和 AMD 架构"
        exit 1
        ;;
    esac
}
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
        return 0
    else
        echo "$command 命令执行失败，错误信息如下："
        echo "$output"
        return 1
    fi
}

is_command_available() {
    command="$1"
    if command -v "$command" >/dev/null 2>&1; then
        echo "$command 可用"
        return 0
    else
        echo "$command 不可用"
        return 1
    fi
}

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
edit_docker_daemon() {
    if [ -f "/etc/docker/daemon.json" ]; then
        echo "File \"/etc/docker/daemon.json\" exists"

        check_command_success "mv /etc/docker/daemon.json  /etc/docker/daemon.json.back"
        if [ $? -eq 0 ]; then

            is_command_available "curl"
            if [ $? -eq 0 ]; then
                culr -o /etc/docker/daemon.json https://chfs.sxxpqp.top:8443/chfs/shared/docker/daemon.json
            else
                is_command_available "wget"
                if [ $? -eq 0 ]; then
                    wget -O /etc/docker/daemon.json https://chfs.sxxpqp.top:8443/chfs/shared/docker/daemon.json
                fi
            fi

            check_command_success "systemctl daemon-reload"
            check_command_success "systemctl reload docker"
            if [ $? -eq 0 ]; then
                echo "配置daemon.json成功"
            fi
        fi
    else
        is_command_available "curl"
        if [ $? -eq 0 ]; then
            culr -o /etc/docker/daemon.json https://chfs.sxxpqp.top:8443/chfs/shared/docker/daemon.json
        else
            is_command_available "wget"
            if [ $? -eq 0 ]; then
                wget -O /etc/docker/daemon.json https://chfs.sxxpqp.top:8443/chfs/shared/docker/daemon.json
            fi
        fi

        check_command_success "systemctl daemon-reload"
        check_command_success "systemctl reload docker"
        if [ $? -eq 0 ]; then
            echo "配置daemon.json成功"
        fi
    fi

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
    echo "1: 安装 Docker CE..."
    echo "2: 卸载 Docker..."
    echo "3: 启动helloworld..."
    echo "4: 配置daemon.json..."
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
    4)
        echo "配置daemon.json..."
        edit_docker_daemon
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
//dns 客户端配置
dns_menu() {
    if grep -iq "ubuntu" /etc/os-release; then
        #    sed -i "1i nameserver 223.5.5.5" /etc/resolv.conf
        vi /etc/resolv.conf
        if [ $? -eq 0 ]; then
            echo "添加dns到resolv.conf成功"

            check_command_success "systemctl restart systemd-resolved"
            check_command_success "systemctl enable systemd-resolved"

            check_command_success 'mv /etc/resolv.conf /run/systemd/resolve/resolv.conf'
            check_command_success 'ln -s /run/systemd/resolve/resolv.conf /etc/'
            check_command_success "ping -c 4 jd.com"
            if [ $? -eq 0 ]; then
                echo "resolv.conf 添加DNS配置成功"

            fi
        else
            echo "添加dns到resolv.conf失败"
        fi

    fi
}
ubuntu-update-kernal() {
    ehco "开始更新内核"

}
ubuntu_fireware_downlaod_edit() {

    cd "$DOWNLOAD_DIR" || {
        echo "无法进入下载目录"
        exit 1
    }

    # 下载固件文件
    echo "正在下载固件文件..."
    wget --no-check-certificate "$FIRMWARE_URL" -O "$FIRMWARE_FILE"
    if [ $? -ne 0 ]; then
        curl -o "$FIRMWARE_FILE" "$FIRMWARE_URL"
    fi

    echo "下载完成：$FIRMWARE_FILE"

    # 解压固件文件
    echo "正在解压固件文件..."
    tar -xvzf "$FIRMWARE_FILE" -C "$DOWNLOAD_DIR"
    if [ $? -ne 0 ]; then
        echo "解压失败。"
        exit 1
    fi

    # 创建 /lib/firmware/updates/ 目录（如果不存在）
    if [ ! -d /lib/firmware/updates/ ]; then
        mkdir -p /lib/firmware/updates/
        echo "已创建 /lib/firmware/updates/ 目录"
    fi

    # 移动固件文件到 /lib/firmware/updates/
    echo "正在移动固件文件到 /lib/firmware/updates/ ..."
    sudo mv "$DOWNLOAD_DIR"/* /lib/firmware/updates/
    echo "所有固件文件已移动到 /lib/firmware/updates/"

    # 更新 initramfs
    echo "正在更新 initramfs..."
    sudo update-initramfs -u
    echo "initramfs 已更新"

    # 清理下载的临时文件
    rm -rf "$DOWNLOAD_DIR"
    echo "清理完成"
    echo "操作完成，请重启系统以应用新的固件文件"
}
ubuntu-update-firmware() {

    # 创建下载目录
    if [ -f "$DOWNLOAD_DIR" ]; then
        echo "File \"$DOWNLOAD_DIR\" exists"
        ubuntu_fireware_downlaod_edit
    else
        mkdir -p "$DOWNLOAD_DIR"
        ubuntu_fireware_downlaod_edit
    fi
}
install_other_tools_menu() {
    echo "-----------------"
    echo "请选择您要执行的操作:"
    echo "1: ubuntu升级内核到5.19"
    echo "2: Firmware固件更新"
    echo "3: 配置XXXXXXXX"
    echo "b: 返回主菜单"
    echo "q: 退出"
    echo "-----------------"
    read -p "请输入您的选择: " choice
    case "$choice" in
    1)
        echo "ubuntu升级内核到5.19..."
        ubuntu-update-kernal
        ;;
    2)
        echo "Firmware固件更新..."
        ubuntu-update-firmware
        ;;
    3)
        echo "nginx安装||卸载"
        xxxx
        ;;
    b) main_menu ;;
    q) exit_program_menu ;;
    *)
        echo "无效选择，请重新选择。"
        install_other_tools_menu
        ;;
    esac
}
# 主菜单函数
main_menu() {
    echo "-----------------"
    echo "请选择您要执行的操作:"
    echo "1: 安装 Docker"
    echo "2: 部署docker-compose服务"
    echo "3: 配置dns"
    echo "4: 安装其他工具"
    echo "q: 退出"
    echo "-----------------"
    read -p "请输入您的选择: " choice
    case "$choice" in
    1) install_docker_menu ;;
    2) deploy_service_menu ;;
    3) dns_menu ;;
    4) install_other_tools_menu ;;
    q) exit_program_menu ;;
    *)
        echo "无效选择，请重新选择。"
        main_menu
        ;;
    esac
}

# 查看系统架构
check_architecture
# 是否为root
check_root
# 调用主菜单
main_menu
