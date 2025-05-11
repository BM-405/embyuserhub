#!/bin/bash
# EmbyUserHub 一键安装/管理脚本
# 版本: 1.2.0
# 日期: 2025-05-11

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # 重置颜色

# 脚本版本
SCRIPT_VERSION="1.2.0-2025_05_11"

# 检测操作系统
OS_NAME=""
OS_VERSION=""
OS_ARCH=""

# 检测Docker
DOCKER_INSTALLED=false
DOCKER_VERSION=""

# 配置项
LATEST_VERSION=""
INSTALLED_VERSION=""
CONTAINER_NAME="embyuserhub"
DATA_DIR="/opt/embyuserhub/data"
CONFIG_DIR="/opt/embyuserhub/config"
NETWORK_MODE="bridge" # 默认网络模式
FLASK_KEY="" # Flask会话密钥

# 镜像源选择
select_image_source() {
    echo -e "${YELLOW}请选择镜像源:${NC}"
    echo -e "${CYAN}1. Docker Hub (推荐，国际访问)${NC}"
    echo -e "${CYAN}2. 私有镜像库 (中国地区可能更快)${NC}"
    read -p "> " SOURCE_OPTION

    if [ "$SOURCE_OPTION" == "1" ]; then
        REGISTRY=""
        NAMESPACE="mmbao"
        IMAGE_NAME="embyuserhub"
    else
        # 原有的配置
        REGISTRY="docker.mmdns.top"
        NAMESPACE="embyuserhub"
        IMAGE_NAME="user-hub"
    fi
}

# 生成 Flask Secret Key
generate_flask_secret_key() {
    echo -e "${YELLOW}正在生成Flask会话密钥...${NC}"
    FLASK_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
    echo -e "${GREEN}Flask会话密钥已生成${NC}"
}

# Banner 显示
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "    ______          __          __  __               __  __      __  "
    echo "   / ____/___ ___  / /_  __  __/ / / /_______  _____/ / / /_  __/ /_ "
    echo "  / __/ / __ \`__ \/ __ \/ / / / / / / ___/ _ \/ ___/ /_/ / / / / __ \\"
    echo " / /___/ / / / / / /_/ / /_/ / /_/ (__  )  __/ /  / __  / /_/ / /_/ /"
    echo "/_____/_/ /_/ /_/_.___/\__, /\____/____/\___/_/  /_/ /_/\__,_/_.___/ "
    echo "                      /____/                                         "
    echo -e "${NC}"
    echo -e "${BOLD}————————— EmbyUserHub 一键安装/管理工具 —————————${NC}"
    echo -e "${CYAN}版本：${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}Copyright (c) 2025 EmbyUserHub Team${NC}"
    echo -e "${CYAN}马小兔制作${NC}"
    echo -e "${BOLD}———————————————————————————————————————————${NC}"
}

# 检测系统信息
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS_NAME=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS_NAME="debian"
        OS_VERSION=$(cat /etc/debian_version)
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi

    OS_ARCH=$(uname -m)
    case $OS_ARCH in
        x86_64) OS_ARCH="64bit" ;;
        aarch64) OS_ARCH="arm64" ;;
        armv7l) OS_ARCH="armv7" ;;
        *) ;;
    esac
}

# 检测Docker
detect_docker() {
    if command -v docker &>/dev/null; then
        DOCKER_INSTALLED=true
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "未知")
    else
        DOCKER_INSTALLED=false
        DOCKER_VERSION="未安装"
    fi
}

# 检测IP地址
get_ip_info() {
    IP_ADDRESS=$(curl -s https://api.ipify.org || echo "未知")
    IP_LOCATION=$(curl -s "https://ip.useragentinfo.com/json?ip=$IP_ADDRESS" | grep -o '"province":"[^"]*","city":"[^"]*"' | sed 's/"province":"//;s/","city":"/ /;s/"//' || echo "未知")
}

# 检测EmbyUserHub状态
check_embyuserhub_status() {
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            EMBY_STATUS="运行中"
            INSTALLED_VERSION=$(docker inspect ${CONTAINER_NAME} -f '{{.Config.Image}}' | awk -F ":" '{print $2}' || echo "未知")
        else
            EMBY_STATUS="已停止"
        fi
    else
        EMBY_STATUS="未安装"
    fi
}

# 安装Docker
install_docker() {
    echo -e "${YELLOW}正在安装Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}Docker安装失败！${NC}"
        return 1
    fi
    
    # 启动Docker服务
    systemctl enable docker
    systemctl start docker
    
    echo -e "${GREEN}Docker安装成功！${NC}"
    DOCKER_INSTALLED=true
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "未知")
}

# 检查并拉取最新版本
check_latest_version() {
    echo -e "${YELLOW}正在检查EmbyUserHub最新版本...${NC}"
    
    # 使用GitHub API获取最新版本
    GITHUB_API="https://api.github.com/repos/BM-405/embyuserhub/releases/latest"
    LATEST_VERSION=$(curl -s "$GITHUB_API" | grep -Po '"tag_name": "\K.*?(?=")' || echo "v2.9.8.1")
    
    # 移除v前缀（如果存在）
    LATEST_VERSION=${LATEST_VERSION#v}
    
    # 如果获取失败，使用默认版本
    if [ -z "$LATEST_VERSION" ]; then
        echo -e "${YELLOW}无法获取最新版本信息，使用默认版本...${NC}"
        LATEST_VERSION="2.9.8.1"
    fi
    
    echo -e "${GREEN}最新版本: ${LATEST_VERSION}${NC}"
}

# 安装EmbyUserHub
install_embyuserhub() {
    echo -e "${YELLOW}开始安装EmbyUserHub...${NC}"
    
    # 创建目录
    mkdir -p ${DATA_DIR} ${CONFIG_DIR}
    
    # 如果Flask密钥为空，则生成
    if [ -z "$FLASK_KEY" ]; then
        generate_flask_secret_key
    fi
    
    # 镜像地址
    DOCKER_IMAGE=${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}
    # 如果REGISTRY为空，则不添加/
    if [ -z "$REGISTRY" ]; then
        DOCKER_IMAGE=${NAMESPACE}/${IMAGE_NAME}
    fi
    
    # 拉取镜像
    echo -e "${YELLOW}拉取镜像: ${DOCKER_IMAGE}:${LATEST_VERSION}${NC}"
    docker pull ${DOCKER_IMAGE}:${LATEST_VERSION}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}镜像拉取失败！${NC}"
        return 1
    fi
    
    # 停止并删除旧容器
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}停止并删除旧容器...${NC}"
        docker stop ${CONTAINER_NAME} &>/dev/null
        docker rm ${CONTAINER_NAME} &>/dev/null
    fi
    
    # 运行容器
    echo -e "${YELLOW}启动EmbyUserHub容器...${NC}"
    docker run -d \
        --name ${CONTAINER_NAME} \
        --network ${NETWORK_MODE} \
        -p 29045:29045 \
        -v ${DATA_DIR}:/app/data \
        -v ${CONFIG_DIR}:/app/config \
        -e FLASK_SECRET_KEY=${FLASK_KEY} \
        --restart always \
        ${DOCKER_IMAGE}:${LATEST_VERSION}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}容器启动失败！可能是网络模式不兼容，尝试使用默认bridge模式...${NC}"
        NETWORK_MODE="bridge"
        docker run -d \
            --name ${CONTAINER_NAME} \
            --network ${NETWORK_MODE} \
            -p 29045:29045 \
            -v ${DATA_DIR}:/app/data \
            -v ${CONFIG_DIR}:/app/config \
            -e FLASK_SECRET_KEY=${FLASK_KEY} \
            --restart always \
            ${DOCKER_IMAGE}:${LATEST_VERSION}
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}容器启动失败！${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}EmbyUserHub 安装成功！${NC}"
    echo -e "${GREEN}访问地址: http://YOUR_IP:29045${NC}"
    echo -e "${GREEN}当前网络模式: ${NETWORK_MODE}${NC}"
    INSTALLED_VERSION=${LATEST_VERSION}
    EMBY_STATUS="运行中"
}

# 更新EmbyUserHub
update_embyuserhub() {
    echo -e "${YELLOW}开始更新EmbyUserHub...${NC}"
    
    if [ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]; then
        echo -e "${GREEN}当前已是最新版本！${NC}"
        return 0
    fi
    
    # 选择镜像源
    select_image_source
    
    # 如果Flask密钥为空，则生成
    if [ -z "$FLASK_KEY" ]; then
        generate_flask_secret_key
    fi
    
    # 备份数据库
    echo -e "${YELLOW}备份数据库...${NC}"
    BACKUP_DIR="${DATA_DIR}/backups"
    mkdir -p ${BACKUP_DIR}
    BACKUP_FILE="${BACKUP_DIR}/database_$(date +%Y%m%d_%H%M%S).db"
    docker exec ${CONTAINER_NAME} cp /app/data/database.db ${BACKUP_FILE} || echo -e "${YELLOW}备份可能失败，但将继续更新${NC}"
    
    # 镜像地址
    DOCKER_IMAGE=${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}
    # 如果REGISTRY为空，则不添加/
    if [ -z "$REGISTRY" ]; then
        DOCKER_IMAGE=${NAMESPACE}/${IMAGE_NAME}
    fi
    
    # 拉取新镜像
    echo -e "${YELLOW}拉取新镜像: ${DOCKER_IMAGE}:${LATEST_VERSION}${NC}"
    docker pull ${DOCKER_IMAGE}:${LATEST_VERSION}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}镜像拉取失败！${NC}"
        return 1
    fi
    
    # 停止并删除旧容器
    echo -e "${YELLOW}停止并删除旧容器...${NC}"
    docker stop ${CONTAINER_NAME}
    docker rm ${CONTAINER_NAME}
      # 运行新容器
    echo -e "${YELLOW}启动新版本容器...${NC}"
    docker run -d \
        --name ${CONTAINER_NAME} \
        --network ${NETWORK_MODE} \
        -p 29045:29045 \
        -v ${DATA_DIR}:/app/data \
        -v ${CONFIG_DIR}:/app/config \
        -e FLASK_SECRET_KEY=${FLASK_KEY} \
        --restart always \
        ${DOCKER_IMAGE}:${LATEST_VERSION}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}容器启动失败！可能是网络模式不兼容，尝试使用默认bridge模式...${NC}"
        NETWORK_MODE="bridge"
        docker run -d \
            --name ${CONTAINER_NAME} \
            --network ${NETWORK_MODE} \
            -p 29045:29045 \
            -v ${DATA_DIR}:/app/data \
            -v ${CONFIG_DIR}:/app/config \
            -e FLASK_SECRET_KEY=${FLASK_KEY} \
            --restart always \
            ${DOCKER_IMAGE}:${LATEST_VERSION}
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}容器启动失败！${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}EmbyUserHub 更新成功！${NC}"
    echo -e "${GREEN}版本: ${INSTALLED_VERSION} -> ${LATEST_VERSION}${NC}"
    echo -e "${GREEN}当前网络模式: ${NETWORK_MODE}${NC}"
    INSTALLED_VERSION=${LATEST_VERSION}
}

# 卸载EmbyUserHub
uninstall_embyuserhub() {
    echo -e "${YELLOW}开始卸载EmbyUserHub...${NC}"
    
    # 停止并删除容器
    docker stop ${CONTAINER_NAME} &>/dev/null
    docker rm ${CONTAINER_NAME} &>/dev/null
    
    # 询问是否删除数据
    echo -e "${YELLOW}是否删除所有数据？ (yes/no)${NC}"
    read -p "> " DELETE_DATA
    
    if [ "$DELETE_DATA" == "yes" ]; then
        echo -e "${YELLOW}删除数据目录: ${DATA_DIR}${NC}"
        rm -rf ${DATA_DIR}
        echo -e "${YELLOW}删除配置目录: ${CONFIG_DIR}${NC}"
        rm -rf ${CONFIG_DIR}
    else
        echo -e "${YELLOW}保留数据目录: ${DATA_DIR}${NC}"
        echo -e "${YELLOW}保留配置目录: ${CONFIG_DIR}${NC}"
    fi
    
    echo -e "${GREEN}EmbyUserHub 卸载完成！${NC}"
    EMBY_STATUS="未安装"
}

# 重启EmbyUserHub
restart_embyuserhub() {
    echo -e "${YELLOW}重启EmbyUserHub...${NC}"
    docker restart ${CONTAINER_NAME}
    if [ $? -ne 0 ]; then
        echo -e "${RED}重启失败！${NC}"
        return 1
    fi
    echo -e "${GREEN}重启成功！${NC}"
}

# 查看日志
view_logs() {
    echo -e "${YELLOW}查看EmbyUserHub日志 (按Ctrl+C退出)${NC}"
    docker logs -f ${CONTAINER_NAME}
}

# 备份数据库
backup_database() {
    echo -e "${YELLOW}备份数据库...${NC}"
    BACKUP_DIR="${DATA_DIR}/backups"
    mkdir -p ${BACKUP_DIR}
    BACKUP_FILE="${BACKUP_DIR}/database_$(date +%Y%m%d_%H%M%S).db"
    docker exec ${CONTAINER_NAME} cp /app/data/database.db ${BACKUP_FILE}
    if [ $? -ne 0 ]; then
        echo -e "${RED}备份失败！${NC}"
        return 1
    fi
    echo -e "${GREEN}数据库备份成功: ${BACKUP_FILE}${NC}"
}

# 恢复数据库
restore_database() {
    echo -e "${YELLOW}可用的数据库备份:${NC}"
    BACKUP_DIR="${DATA_DIR}/backups"
    if [ ! -d "${BACKUP_DIR}" ]; then
        echo -e "${RED}备份目录不存在!${NC}"
        return 1
    fi
    
    # 列出备份文件
    BACKUPS=($(ls -1 ${BACKUP_DIR}/database_*.db 2>/dev/null))
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${RED}没有找到备份文件!${NC}"
        return 1
    fi
    
    # 显示备份列表
    for i in "${!BACKUPS[@]}"; do
        echo -e "[${i}] $(basename ${BACKUPS[$i]})"
    done
    
    # 选择要恢复的备份
    echo -e "${YELLOW}请选择要恢复的备份 [0-$((${#BACKUPS[@]}-1))]${NC}"
    read -p "> " BACKUP_INDEX
    
    if [[ ! $BACKUP_INDEX =~ ^[0-9]+$ ]] || [ $BACKUP_INDEX -ge ${#BACKUPS[@]} ]; then
        echo -e "${RED}无效的选择!${NC}"
        return 1
    fi
    
    SELECTED_BACKUP=${BACKUPS[$BACKUP_INDEX]}
    echo -e "${YELLOW}即将恢复: $(basename ${SELECTED_BACKUP})${NC}"
    echo -e "${RED}警告: 这将覆盖当前数据库，是否继续? (yes/no)${NC}"
    read -p "> " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${YELLOW}恢复操作已取消${NC}"
        return 0
    fi
    
    # 停止容器
    echo -e "${YELLOW}停止容器...${NC}"
    docker stop ${CONTAINER_NAME}
    
    # 恢复数据库
    echo -e "${YELLOW}恢复数据库...${NC}"
    cp ${SELECTED_BACKUP} ${DATA_DIR}/database.db
    if [ $? -ne 0 ]; then
        echo -e "${RED}恢复失败！${NC}"
        # 重启容器
        docker start ${CONTAINER_NAME}
        return 1
    fi
    
    # 启动容器
    echo -e "${YELLOW}启动容器...${NC}"
    docker start ${CONTAINER_NAME}
    echo -e "${GREEN}数据库恢复成功!${NC}"
}

# 检查并创建两步验证备份/重置功能
manage_2fa() {
    echo -e "${YELLOW}两步验证(2FA)管理${NC}"
    echo -e "${CYAN}1. 备份两步验证配置${NC}"
    echo -e "${CYAN}2. 重置两步验证(当无法登录时使用)${NC}"
    echo -e "${CYAN}0. 返回上级菜单${NC}"
    
    read -p "请选择操作 [0-2]: " OPTION
    
    case $OPTION in
        1)
            echo -e "${YELLOW}备份两步验证配置...${NC}"
            BACKUP_DIR="${DATA_DIR}/backups/2fa"
            mkdir -p ${BACKUP_DIR}
            BACKUP_FILE="${BACKUP_DIR}/secure_config_$(date +%Y%m%d_%H%M%S).json"
            docker cp ${CONTAINER_NAME}:/app/data/secure_config.json ${BACKUP_FILE}
            docker cp ${CONTAINER_NAME}:/app/data/.key ${BACKUP_FILE}.key
            if [ $? -ne 0 ]; then
                echo -e "${RED}备份失败！${NC}"
                return 1
            fi
            echo -e "${GREEN}两步验证配置备份成功: ${BACKUP_FILE}${NC}"
            ;;
        2)
            echo -e "${RED}警告: 此操作将删除所有两步验证设置，是否继续? (yes/no)${NC}"
            read -p "> " CONFIRM
            
            if [ "$CONFIRM" != "yes" ]; then
                echo -e "${YELLOW}操作已取消${NC}"
                return 0
            fi
            
            echo -e "${YELLOW}重置两步验证...${NC}"
            docker exec ${CONTAINER_NAME} rm -f /app/data/secure_config.json
            if [ $? -ne 0 ]; then
                echo -e "${RED}重置失败！${NC}"
                return 1
            fi
            echo -e "${GREEN}两步验证已重置，请重启容器使更改生效${NC}"
            echo -e "${YELLOW}是否立即重启容器? (yes/no)${NC}"
            read -p "> " RESTART
            
            if [ "$RESTART" == "yes" ]; then
                restart_embyuserhub
            fi
            ;;
        0)
            return 0
            ;;
        *)
            echo -e "${RED}无效的选择!${NC}"
            ;;
    esac
}

# 主菜单
main_menu() {
    show_banner
    detect_system
    detect_docker
    get_ip_info
    check_embyuserhub_status
    check_latest_version
    
    echo -e "——————————————————————————————————————————————————————————————————————————————"
    echo -e "1、安装/更新 EmbyUserHub                     当前状态：${EMBY_STATUS}"
    echo -e "2、重启 EmbyUserHub                          当前版本：${INSTALLED_VERSION}"
    echo -e "3、查看 EmbyUserHub 日志                     可用版本：${LATEST_VERSION}"
    echo -e "4、卸载 EmbyUserHub"
    echo -e "5、数据库备份/恢复"
    echo -e "6、两步验证(2FA)管理(解决无法登录问题)"
    echo -e "7、系统信息 | ${OS_NAME} ${OS_VERSION}, ${OS_ARCH}"
    echo -e "8、高级工具 | Docker: ${DOCKER_VERSION}, IP: ${IP_ADDRESS} ${IP_LOCATION}"
    echo -e "0、退出脚本"
    echo -e "——————————————————————————————————————————————————————————————————————————————"
    
    read -p "请输入数字 [0-8]: " choice
    
    case $choice in
        1)
            if [ "$DOCKER_INSTALLED" != "true" ]; then
                echo -e "${RED}Docker未安装，是否安装Docker? (yes/no)${NC}"
                read -p "> " INSTALL_DOCKER
                if [ "$INSTALL_DOCKER" == "yes" ]; then
                    install_docker
                else
                    echo -e "${RED}安装Docker被取消，无法继续安装EmbyUserHub${NC}"
                    sleep 2
                    return
                fi
            fi
              if [ "$EMBY_STATUS" == "未安装" ]; then
                # 选择镜像源
                select_image_source
                
                # 生成Flask Secret Key
                generate_flask_secret_key
                
                install_embyuserhub
            else
                echo -e "${YELLOW}EmbyUserHub已安装，是否更新? (yes/no)${NC}"
                read -p "> " UPDATE
                if [ "$UPDATE" == "yes" ]; then
                    update_embyuserhub
                fi
            fi
            ;;
        2)
            if [ "$EMBY_STATUS" == "未安装" ]; then
                echo -e "${RED}EmbyUserHub未安装!${NC}"
                sleep 2
                return
            fi
            restart_embyuserhub
            ;;
        3)
            if [ "$EMBY_STATUS" == "未安装" ]; then
                echo -e "${RED}EmbyUserHub未安装!${NC}"
                sleep 2
                return
            fi
            view_logs
            ;;
        4)
            if [ "$EMBY_STATUS" == "未安装" ]; then
                echo -e "${RED}EmbyUserHub未安装!${NC}"
                sleep 2
                return
            fi
            echo -e "${RED}确认卸载EmbyUserHub? (yes/no)${NC}"
            read -p "> " CONFIRM
            if [ "$CONFIRM" == "yes" ]; then
                uninstall_embyuserhub
            fi
            ;;
        5)
            if [ "$EMBY_STATUS" == "未安装" ]; then
                echo -e "${RED}EmbyUserHub未安装!${NC}"
                sleep 2
                return
            fi
            echo -e "${YELLOW}数据库管理${NC}"
            echo -e "${CYAN}1. 备份数据库${NC}"
            echo -e "${CYAN}2. 恢复数据库${NC}"
            echo -e "${CYAN}0. 返回上级菜单${NC}"
            read -p "请选择操作 [0-2]: " DB_OPTION
            
            case $DB_OPTION in
                1) backup_database ;;
                2) restore_database ;;
                0) return ;;
                *) echo -e "${RED}无效的选择!${NC}" ;;
            esac
            ;;
        6)
            if [ "$EMBY_STATUS" == "未安装" ]; then
                echo -e "${RED}EmbyUserHub未安装!${NC}"
                sleep 2
                return
            fi
            manage_2fa
            ;;
        7)
            echo -e "${YELLOW}系统信息${NC}"
            echo "操作系统: $OS_NAME $OS_VERSION"
            echo "架构: $OS_ARCH"
            echo "内核: $(uname -r)"
            echo "CPU: $(grep -c processor /proc/cpuinfo) 核"
            echo "内存: $(free -h | grep Mem | awk '{print $2}')"
            echo "磁盘: $(df -h / | awk 'NR==2{print $2}') (总计), $(df -h / | awk 'NR==2{print $4}') (可用)"
            echo
            ;;
          8)
            # 进入高级工具子菜单
            advanced_tools_menu
            # 不再需要额外的Enter提示
            ;;
        0)
            echo -e "${GREEN}感谢使用 EmbyUserHub 安装工具!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择，请重新输入!${NC}"
            sleep 1
            ;;
    esac
}

# 高级工具子菜单
advanced_tools_menu() {
    while true; do
        show_banner
        
        echo -e "——————————————— ${YELLOW}高级工具${NC} ———————————————"
        echo -e "${CYAN}1. 查看Docker容器列表${NC}"
        echo -e "${CYAN}2. 查看Docker镜像列表${NC}"
        echo -e "${CYAN}3. 清理未使用的Docker资源${NC}"
        echo -e "${CYAN}4. 检查网络连接${NC}"
        echo -e "${CYAN}5. 清理过期会话文件${NC}"
        echo -e "${CYAN}6. 容器网络模式设置             当前状态：${NETWORK_MODE}${NC}"
        echo -e "${CYAN}7. 清理系统操作日志${NC}"
        echo -e "${CYAN}8. 清理应用日志文件${NC}"
        echo -e "${CYAN}0. 返回主菜单${NC}"
        echo -e "———————————————————————————————————"
        
        read -p "请选择操作 [0-8]: " ADV_OPTION
            
        case $ADV_OPTION in
            1) 
                echo -e "${YELLOW}Docker容器列表:${NC}"
                docker ps -a
                read -p "按Enter键继续..." enter
                ;;
            2)
                echo -e "${YELLOW}Docker镜像列表:${NC}"
                docker images
                read -p "按Enter键继续..." enter
                ;;
            3)
                echo -e "${YELLOW}清理未使用的Docker资源...${NC}"
                docker system prune -f
                echo -e "${GREEN}清理完成!${NC}"
                read -p "按Enter键继续..." enter
                ;;
            4)
                echo -e "${YELLOW}检查网络连接...${NC}"
                ping -c 4 www.baidu.com
                ping -c 4 docker.mmdns.top
                read -p "按Enter键继续..." enter
                ;;
            5)
                if [ "$EMBY_STATUS" == "未安装" ]; then
                    echo -e "${RED}EmbyUserHub未安装!${NC}"
                    read -p "按Enter键继续..." enter
                    continue
                fi
                echo -e "${YELLOW}清理会话文件...${NC}"
                echo -e "${YELLOW}请选择清理选项:${NC}"
                echo -e "${CYAN}1. 清理1天前的过期会话${NC}"
                echo -e "${CYAN}2. 清理3天前的过期会话${NC}"
                echo -e "${CYAN}3. 清理7天前的过期会话${NC}"
                echo -e "${CYAN}4. 清理全部会话文件${NC}"
                echo -e "${CYAN}0. 取消操作${NC}"
                
                read -p "请选择操作 [0-4]: " CLEAN_OPTION
                
                case $CLEAN_OPTION in
                    1|2|3|4)
                        if [ $CLEAN_OPTION -eq 1 ]; then
                            DAYS=1
                        elif [ $CLEAN_OPTION -eq 2 ]; then
                            DAYS=3
                        elif [ $CLEAN_OPTION -eq 3 ]; then
                            DAYS=7
                        else
                            DAYS=0
                        fi
                        
                        SESSIONS_DIR="${DATA_DIR}/flask_sessions"
                        if [ ! -d "$SESSIONS_DIR" ]; then
                            echo -e "${RED}会话目录不存在!${NC}"
                            read -p "按Enter键继续..." enter
                            continue
                        fi
                        
                        # 统计文件
                        echo -e "${YELLOW}统计会话文件...${NC}"
                        TOTAL_FILES=$(find "$SESSIONS_DIR" -type f | wc -l)
                        echo -e "${CYAN}当前会话文件总数: ${TOTAL_FILES}${NC}"
                        
                        if [ $DAYS -eq 0 ]; then
                            echo -e "${RED}警告: 即将清理所有会话文件，用户将需要重新登录，是否继续? (yes/no)${NC}"
                        else
                            echo -e "${YELLOW}将清理${DAYS}天前的过期会话，是否继续? (yes/no)${NC}"
                        fi
                        
                        read -p "> " CONFIRM
                        if [ "$CONFIRM" != "yes" ]; then
                            echo -e "${YELLOW}操作已取消${NC}"
                            read -p "按Enter键继续..." enter
                            continue
                        fi
                        
                        if [ $DAYS -eq 0 ]; then
                            echo -e "${YELLOW}清理所有会话文件...${NC}"
                            find "$SESSIONS_DIR" -type f -delete
                            DELETED=$(($TOTAL_FILES - $(find "$SESSIONS_DIR" -type f | wc -l)))
                            echo -e "${GREEN}已清理${DELETED}个会话文件${NC}"
                        else
                            echo -e "${YELLOW}清理${DAYS}天前的会话文件...${NC}"
                            find "$SESSIONS_DIR" -type f -mtime +$DAYS -delete
                            DELETED=$(($TOTAL_FILES - $(find "$SESSIONS_DIR" -type f | wc -l)))
                            echo -e "${GREEN}已清理${DELETED}个过期会话文件${NC}"
                        fi
                        
                        echo -e "${YELLOW}是否需要重启容器使更改立即生效? (yes/no)${NC}"
                        read -p "> " RESTART
                        if [ "$RESTART" == "yes" ]; then
                            restart_embyuserhub
                        fi
                        ;;
                    0)
                        echo -e "${YELLOW}操作已取消${NC}"
                        ;;
                    *)
                        echo -e "${RED}无效的选择!${NC}"
                        ;;
                esac
                read -p "按Enter键继续..." enter
                ;;
            6)
                echo -e "${YELLOW}设置容器网络模式${NC}"
                echo -e "${YELLOW}当前网络模式: ${NETWORK_MODE}${NC}"
                echo -e "${YELLOW}请选择网络模式:${NC}"
                echo -e "${CYAN}1. bridge (默认Docker网络模式，隔离网络)${NC}"
                echo -e "${CYAN}2. host (与宿主机共享网络，性能好但隔离性差)${NC}"
                echo -e "${CYAN}3. none (完全禁用网络功能)${NC}"
                echo -e "${CYAN}4. 自定义网络模式${NC}"
                echo -e "${CYAN}0. 取消操作${NC}"
                
                read -p "请选择网络模式 [0-4]: " NET_OPTION
                
                case $NET_OPTION in
                    1)
                        NETWORK_MODE="bridge"
                        ;;
                    2)
                        NETWORK_MODE="host"
                        ;;
                    3)
                        NETWORK_MODE="none"
                        ;;
                    4)
                        echo -e "${YELLOW}请输入自定义网络模式:${NC}"
                        read -p "> " CUSTOM_MODE
                        if [ -n "$CUSTOM_MODE" ]; then
                            NETWORK_MODE="$CUSTOM_MODE"
                        else
                            echo -e "${RED}输入无效，保持原网络模式!${NC}"
                        fi
                        ;;
                    0)
                        echo -e "${YELLOW}操作已取消${NC}"
                        ;;
                    *)
                        echo -e "${RED}无效的选择!${NC}"
                        ;;
                esac
                
                if [ $NET_OPTION -ge 1 -a $NET_OPTION -le 4 ]; then
                    echo -e "${GREEN}网络模式已设置为: ${NETWORK_MODE}${NC}"
                    
                    # 如果容器已经运行，询问是否需要重新创建以应用新的网络模式
                    if [ "$EMBY_STATUS" == "运行中" ]; then
                        echo -e "${YELLOW}已有容器正在运行，需要重新创建容器才能应用新的网络模式。${NC}"
                        echo -e "${YELLOW}是否立即重新创建容器? (yes/no)${NC}"
                        read -p "> " RECREATE
                        
                        if [ "$RECREATE" == "yes" ]; then
                            echo -e "${YELLOW}重新创建容器以应用新网络模式...${NC}"
                            # 停止并删除旧容器
                            docker stop ${CONTAINER_NAME} &>/dev/null
                            docker rm ${CONTAINER_NAME} &>/dev/null
                              # 如果Flask密钥为空，则生成
                            if [ -z "$FLASK_KEY" ]; then
                                generate_flask_secret_key
                            fi
                            
                            # 镜像地址
                            DOCKER_IMAGE=${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}
                            # 如果REGISTRY为空，则不添加/
                            if [ -z "$REGISTRY" ]; then
                                DOCKER_IMAGE=${NAMESPACE}/${IMAGE_NAME}
                            fi
                            
                            # 运行新容器
                            docker run -d \
                                --name ${CONTAINER_NAME} \
                                --network ${NETWORK_MODE} \
                                -p 29045:29045 \
                                -v ${DATA_DIR}:/app/data \
                                -v ${CONFIG_DIR}:/app/config \
                                -e FLASK_SECRET_KEY=${FLASK_KEY} \
                                --restart always \
                                ${DOCKER_IMAGE}:${INSTALLED_VERSION}
                                
                            if [ $? -ne 0 ]; then
                                echo -e "${RED}容器重建失败！可能是网络模式不兼容，恢复为bridge模式。${NC}"
                                NETWORK_MODE="bridge"
                                docker run -d \
                                    --name ${CONTAINER_NAME} \
                                    --network ${NETWORK_MODE} \
                                    -p 29045:29045 \
                                    -v ${DATA_DIR}:/app/data \
                                    -v ${CONFIG_DIR}:/app/config \
                                    -e FLASK_SECRET_KEY=${FLASK_KEY} \
                                    --restart always \
                                    ${DOCKER_IMAGE}:${INSTALLED_VERSION}
                            else
                                echo -e "${GREEN}容器已重建，网络模式: ${NETWORK_MODE}${NC}"
                            fi
                        fi
                    fi
                fi
                
                read -p "按Enter键继续..." enter
                ;;
            7)
                if [ "$EMBY_STATUS" == "未安装" ]; then
                    echo -e "${RED}EmbyUserHub未安装!${NC}"
                    read -p "按Enter键继续..." enter
                    continue
                fi
                echo -e "${YELLOW}清理系统操作日志...${NC}"
                echo -e "${YELLOW}请选择清理选项:${NC}"
                echo -e "${CYAN}1. 清理7天前的操作日志${NC}"
                echo -e "${CYAN}2. 清理30天前的操作日志${NC}"
                echo -e "${CYAN}3. 清理90天前的操作日志${NC}"
                echo -e "${CYAN}4. 清理所有操作日志${NC}"
                echo -e "${CYAN}0. 取消操作${NC}"
                
                read -p "请选择操作 [0-4]: " LOG_OPTION
                
                case $LOG_OPTION in
                    1|2|3|4)
                        if [ $LOG_OPTION -eq 1 ]; then
                            LOG_DAYS=7
                        elif [ $LOG_OPTION -eq 2 ]; then
                            LOG_DAYS=30
                        elif [ $LOG_OPTION -eq 3 ]; then
                            LOG_DAYS=90
                        else
                            LOG_DAYS=0
                        fi
                        
                        if [ $LOG_DAYS -eq 0 ]; then
                            echo -e "${RED}警告: 即将清理所有操作日志记录，是否继续? (yes/no)${NC}"
                            echo -e "${RED}此操作将删除数据库中所有操作历史记录!${NC}"
                        else
                            echo -e "${YELLOW}将清理${LOG_DAYS}天前的操作日志记录，是否继续? (yes/no)${NC}"
                        fi
                        
                        read -p "> " LOG_CONFIRM
                        if [ "$LOG_CONFIRM" != "yes" ]; then
                            echo -e "${YELLOW}操作已取消${NC}"
                            read -p "按Enter键继续..." enter
                            continue
                        fi
                        
                        # 使用Python执行日志清理
                        echo -e "${YELLOW}开始清理操作日志...${NC}"
                        if [ $LOG_DAYS -eq 0 ]; then
                            docker exec ${CONTAINER_NAME} python3 -c "from utils.logger import OperationLogger; cleaned = OperationLogger.clean_old_logs(0); print(f'成功清理所有操作日志，共 {cleaned} 条记录')"
                        else
                            docker exec ${CONTAINER_NAME} python3 -c "from utils.logger import OperationLogger; cleaned = OperationLogger.clean_old_logs(${LOG_DAYS}); print(f'成功清理{LOG_DAYS}天前的操作日志，共 {cleaned} 条记录')"
                        fi
                        
                        if [ $? -ne 0 ]; then
                            echo -e "${RED}日志清理失败，可能是容器中的代码版本不兼容${NC}"
                        else
                            echo -e "${GREEN}操作日志清理完成${NC}"
                        fi
                        ;;
                    0)
                        echo -e "${YELLOW}操作已取消${NC}"
                        ;;
                    *)
                        echo -e "${RED}无效的选择!${NC}"
                        ;;
                esac
                read -p "按Enter键继续..." enter
                ;;
            8)
                if [ "$EMBY_STATUS" == "未安装" ]; then
                    echo -e "${RED}EmbyUserHub未安装!${NC}"
                    read -p "按Enter键继续..." enter
                    continue
                fi
                echo -e "${YELLOW}清理应用日志文件...${NC}"
                echo -e "${YELLOW}请选择清理选项:${NC}"
                echo -e "${CYAN}1. 清理7天前的应用日志${NC}"
                echo -e "${CYAN}2. 清理30天前的应用日志${NC}"
                echo -e "${CYAN}3. 清理90天前的应用日志${NC}"
                echo -e "${CYAN}4. 清理所有应用日志${NC}"
                echo -e "${CYAN}0. 取消操作${NC}"
                
                read -p "请选择操作 [0-4]: " APP_LOG_OPTION
                
                case $APP_LOG_OPTION in
                    1|2|3|4)
                        if [ $APP_LOG_OPTION -eq 1 ]; then
                            APP_LOG_DAYS=7
                        elif [ $APP_LOG_OPTION -eq 2 ]; then
                            APP_LOG_DAYS=30
                        elif [ $APP_LOG_OPTION -eq 3 ]; then
                            APP_LOG_DAYS=90
                        else
                            APP_LOG_DAYS=0
                        fi
                        
                        if [ $APP_LOG_DAYS -eq 0 ]; then
                            echo -e "${RED}警告: 即将清理所有应用日志文件，是否继续? (yes/no)${NC}"
                        else
                            echo -e "${YELLOW}将清理${APP_LOG_DAYS}天前的应用日志文件，是否继续? (yes/no)${NC}"
                        fi
                        
                        read -p "> " APP_LOG_CONFIRM
                        if [ "$APP_LOG_CONFIRM" != "yes" ]; then
                            echo -e "${YELLOW}操作已取消${NC}"
                            read -p "按Enter键继续..." enter
                            continue
                        fi
                        
                        # 清理应用日志文件
                        echo -e "${YELLOW}开始清理应用日志文件...${NC}"
                        if [ $APP_LOG_DAYS -eq 0 ]; then
                            # 清理所有app.log文件
                            docker exec ${CONTAINER_NAME} sh -c "echo '' > /app/data/app.log"
                            docker exec ${CONTAINER_NAME} sh -c "echo '' > /app/logs/app.log"
                            echo -e "${GREEN}已清空所有应用日志文件${NC}"
                        else
                            # 使用find命令找到并删除旧的备份日志文件
                            docker exec ${CONTAINER_NAME} find /app/logs -type f -name "app.log.*" -mtime +$APP_LOG_DAYS -delete
                            docker exec ${CONTAINER_NAME} find /app/data -type f -name "app.log.*" -mtime +$APP_LOG_DAYS -delete
                            
                            # 检查app.log文件的修改时间，如果太旧则清空
                            LOG_AGE_DATA=$(docker exec ${CONTAINER_NAME} find /app/data/app.log -mtime +$APP_LOG_DAYS -print 2>/dev/null | wc -l)
                            LOG_AGE_LOGS=$(docker exec ${CONTAINER_NAME} find /app/logs/app.log -mtime +$APP_LOG_DAYS -print 2>/dev/null | wc -l)
                            
                            # 如果存在且旧于指定天数，则清空
                            if [ "$LOG_AGE_DATA" -gt 0 ]; then
                                docker exec ${CONTAINER_NAME} sh -c "echo '' > /app/data/app.log"
                                echo -e "${GREEN}已清空旧的 data/app.log 文件${NC}"
                            fi
                            
                            if [ "$LOG_AGE_LOGS" -gt 0 ]; then
                                docker exec ${CONTAINER_NAME} sh -c "echo '' > /app/logs/app.log"
                                echo -e "${GREEN}已清空旧的 logs/app.log 文件${NC}"
                            fi
                            
                            echo -e "${GREEN}已清理${APP_LOG_DAYS}天前的应用日志文件${NC}"
                        fi
                        ;;
                    0)
                        echo -e "${YELLOW}操作已取消${NC}"
                        ;;
                    *)
                        echo -e "${RED}无效的选择!${NC}"
                        ;;
                esac
                read -p "按Enter键继续..." enter
                ;;
            0) 
                # 返回主菜单
                return
                ;;
            *)
                echo -e "${RED}无效的选择!${NC}"
                read -p "按Enter键继续..." enter
                ;;
        esac
    done
}

# 主循环
while true; do
    main_menu
done