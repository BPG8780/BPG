#!/bin/bash

#

# automatically configure check_oracle_bot by docker-compose

# Only test on Ubuntu 20.04 LTS Ubuntu 22.04 LTS

BOT_PATH="/opt/check_oracle"

BOT_CONTAINER_NAME="check_oracle_bot"

BOT_IMAGE="techfever/check_oracle_bot"

BOT_IMAGE_TAG="latest"

DC_URL="https://raw.githubusercontent.com/tech-fever/check_oracle_bot/main/docker-compose.yml"

CONFIG_URL="https://raw.githubusercontent.com/tech-fever/check_oracle_bot/main/conf.ini.example"

red='\033[0;31m'

green='\033[0;32m'

yellow='\033[0;33m'

plain='\033[0m'

export PATH=$PATH:/usr/local/bin

pre_check() {

    # check root

    [[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

    ## China_IP

    if [[ -z "${CN}" ]]; then

        if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then

            echo "根据ipapi.co提供的信息，当前IP可能在中国，可能无法完成脚本安装，建议手动安装。"

            read -e -r -p "是否选用中国镜像完成安装? [Y/n] " input

            case $input in

            [yY][eE][sS] | [yY])

                echo "使用中国镜像"

                CN=true

                ;;

            [nN][oO] | [nN])

                echo "不使用中国镜像"

                ;;

            *)

                echo "使用中国镜像"

                CN=true

                ;;

            esac

        fi

    fi

    if [[ -z "${CN}" ]]; then

      Get_Docker_URL="https://get.docker.com"

      Get_Docker_Argu=" "

      GITHUB_URL="github.com"

    else

      Get_Docker_URL="https://get.daocloud.io/docker"

      Get_Docker_Argu=" -s docker --mirror Aliyun"

      GITHUB_URL="github.com"

    fi

}

install_base() {

    (command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1 && command -v getenforce >/dev/null 2>&1) ||

        (install_soft curl wget)

}

install_soft() {

    # Arch官方库不包含selinux等组件

    (command -v yum >/dev/null 2>&1 && yum makecache && yum install $* selinux-policy -y) ||

        (command -v apt >/dev/null 2>&1 && apt update && apt install $* selinux-utils -y) ||

        (command -v pacman >/dev/null 2>&1 && pacman -Syu $*) ||

        (command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install $* selinux-utils -y)

}

install() {

    install_base

    echo -e "> 安装check_oracle_bot机器人"

    # check directory

    if [ ! -d "$BOT_PATH" ]; then

        mkdir -p $BOT_PATH

    else

        echo "您可能已经安装过check_oracle_bot机器人，重复安装会覆盖数据，请注意备份。"

        read -e -r -p "是否退出安装? [Y/n] " input

        case $input in

        [yY][eE][sS] | [yY])

            echo "退出安装"

            exit 0

            ;;

        [nN][oO] | [nN])

            echo "继续安装"

            ;;

        *)

            echo "退出安装"

            exit 0

            ;;

        esac

    fi

    chmod 777 -R $BOT_PATH

    # check docker

    command -v docker >/dev/null 2>&1

    if [[ $? != 0 ]]; then

        echo -e "正在安装 Docker"

        bash <(curl -sL ${Get_Docker_URL}) ${Get_Docker_Argu} >/dev/null 2>&1

        if [[ $? != 0 ]]; then

            echo -e "${red}下载脚本失败，请检查本机能否连接 ${Get_Docker_URL}${plain}"

            return 0

        fi

        systemctl enable docker.service

        systemctl start docker.service

        echo -e "${green}Docker${plain} 安装成功"

    fi

    # check docker compose

    command -v docker-compose >/dev/null 2>&1

    if [[ $? != 0 ]]; then

        echo -e "正在安装 Docker Compose"

        wget -t 2 -T 10 -O /usr/local/bin/docker-compose "https://${GITHUB_URL}/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" >/dev/null 2>&1

        if [[ $? != 0 ]]; then

            echo -e "${red}下载脚本失败，请检查本机能否连接 ${GITHUB_URL}${plain}"

            return 0

        fi

        chmod +x /usr/local/bin/docker-compose

        echo -e "${green}Docker Compose${plain} 安装成功"

    fi

    modify_bot_config 0

    if [[ $# == 0 ]]; then

        before_show_menu

    fi

}

modify_bot_config() {

    echo -e "> 修改check_oracle_bot机器人配置"

    # download docker-compose.yml

    wget -t 2 -T 10 -O /tmp/docker-compose.yml ${DC_URL} >/dev/null 2>&1

    if [[ $? != 0 ]]; then

        echo -e "${red}下载docker-compose.yml失败，请检查本机能否连接 ${DC_URL}${plain}"

        return 0

    fi

    # download conf.ini

    wget -t 2 -T 10 -O /tmp/conf.ini ${CONFIG_URL} >/dev/null 2>&1

    if [[ $? != 0 ]]; then

        echo -e "${red}下载config.yml失败，请检查本机能否连接 ${CONFIG_URL}${plain}"

        return 0

    fi

    # modify conf.ini

    ## modify v2board info

    read -e -r -p "> 请输入你的bot api：" input

    if [[ $input != "" ]]; then

        BOT_TOKEN=$input

    else

        echo -e "${red}输入为空，即将退出。请重新配置bot${plain}"

        return 0

    fi

    echo -e "> 注意：用户id不是username，可发送任意信息给 https://t.me/userinfobot 获取"

    read -e -r -p "> 请输入您的telegram账号id：" input

    DEVELOPER_CHAT_ID=$input

    if [[ $input == "" ]]; then

        echo -e "${yellow}输入为空，程序将不再发送错误信息给您${plain}"

    fi

    DEVELOPER_CHAT_ID=$(echo "$DEVELOPER_CHAT_ID" | sed -e 's/[]\/&$*.^[]/\\&/g')

    sed -i "s/BOT_TOKEN =/BOT_TOKEN = ${BOT_TOKEN}/g" /tmp/conf.ini

    sed -i "s/DEVELOPER_CHAT_ID =/DEVELOPER_CHAT_ID = ${DEVELOPER_CHAT_ID}/g" /tmp/conf.ini

    ec的
