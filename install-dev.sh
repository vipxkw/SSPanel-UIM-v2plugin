#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=`pwd`
# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
software=(Docker Docker_Caddy Docker_Caddy_cloudflare)
operation=(install update_config update_image logs)
# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 此脚本必须以ROOT用户身份运行!" && exit 1

#Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    echo -e "[${green}Info${plain}] 开始安装包 ${depend}"
    ${command} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] 安装失败 ${red}${depend}${plain}"
        echo "请查看: https://teddysun.com/486.html "
        exit 1
    fi
}

# Pre-installation settings
pre_install_docker_compose(){
    echo "您使用哪个面板：SSpanel 0，SSRpanel 1"
    read -p "(v2ray_paneltype (Default 0):" v2ray_paneltype
    [ -z "${v2ray_paneltype}" ] && v2ray_paneltype=0
    echo
    echo "---------------------------"
    echo "v2ray_paneltype = ${v2ray_paneltype}"
    echo "---------------------------"
    echo
    # Set sspanel node_id
    echo "sspanel 节点：id"
    read -p "(Default value: 0 ):" sspanel_node_id
    [ -z "${sspanel_node_id}" ] && sspanel_node_id=0
    echo
    echo "---------------------------"
    echo "sspanel_node_id = ${sspanel_node_id}"
    echo "---------------------------"
    echo
     # Set sspanel node_id
    echo "DNS "
    read -p "(Default value: localhost ):" LDNS
    [ -z "${LDNS}" ] && LDNS="localhost"
    echo
    echo "---------------------------"
    echo "DNS = ${LDNS}"
    echo "---------------------------"
    echo

    # Set caddy cloudflare ddns email
    echo "cloudflare账号(可选)"
    read -p "(Default hulisang@test.com):" cloudflare_email
    [ -z "${cloudflare_email}" ]  && cloudflare_email="hulisang@test.com"
    echo
    echo "---------------------------"
    echo "cloudflare_email = ${cloudflare_email}"
    echo "---------------------------"
    echo

    # Set caddy cloudflare ddns key
    echo "cloudflare密钥(可选)"
    read -p "(Default bbbbbbbbbbbbbbbbbb ):" cloudflare_key
    [ -z "${cloudflare_key}" ] && cloudflare_key="bbbbbbbbbbbbbbbbbb"
    echo
    echo "---------------------------"
    echo "cloudflare_key = ${cloudflare_key}"
    echo "---------------------------"
    echo
    echo

    echo "连接方式 0 webapi 1 for mysql"
    read -p "(v2ray_usemysql (Default 0):" v2ray_usemysql
    [ -z "${v2ray_usemysql}" ] && v2ray_usemysql=0
    echo
    echo "---------------------------"
    echo "v2ray_usemysql = ${v2ray_usemysql}"
    echo "---------------------------"
    echo


    echo "docker映像地址"
    read -p "(image address (Default dnsahvfakcvbpnj/bchdga:1.0):" docker_addresss
    [ -z "${docker_addresss}" ] && docker_addresss="dnsahvfakcvbpnj/bchdga:1.0"
    echo
    echo "---------------------------"
    echo "docker_addresss = ${docker_addresss}"
    echo "---------------------------"
    echo



    echo "请输入（多用户混淆参数表达式，%5m代表取用户特征 md5 的前五位，%id 代表用户id,%suffix 代表上面这个后缀）（可食用：%5m%id.%suffix） MU_REGEX"
    read -p "(MUREGEX (Default %5m%id.%suffix):" MUREGEX
    [ -z "${MUREGEX}" ] && MUREGEX="%5m%id.%suffix"
    echo
    echo "---------------------------"
    echo "MUREGEX = ${MUREGEX}"
    echo "---------------------------"
    echo


    echo "请输入（多用户混淆参数后缀） MU_SUFFIX:"
    read -p "(MUSUFFIX (Default microsoft.com):" MUSUFFIX
    [ -z "${MUSUFFIX}" ] && MUSUFFIX="microsoft.com"
    echo
    echo "---------------------------"
    echo "MUSUFFIX = ${MUSUFFIX}"
    echo "---------------------------"
    echo


    echo "代理协议"
    read -p "(ProxyTCP (Default 0):" ProxyTCP
    [ -z "${ProxyTCP}" ] && ProxyTCP=0
    echo
    echo "---------------------------"
    echo "ProxyTCP = ${ProxyTCP}"
    echo "---------------------------"
    echo


    if [ "${v2ray_usemysql}" -eq 0 ];
        then
      # Set sspanel_url
    echo "SSpanel地址"
    read -p "(没有默认值，请确保输入的内容正确):" sspanel_url
    [ -z "${sspanel_url}" ]
    echo
    echo "---------------------------"
    echo "sspanel_url = ${sspanel_url}"
    echo "---------------------------"
    echo
    # Set sspanel key
    echo "sspanel面板 key"
    read -p "(没有默认值，请确保输入的内容正确):" sspanel_key
    [ -z "${sspanel_key}" ]
    echo
    echo "---------------------------"
    echo "sspanel_key = ${sspanel_key}"
    echo "---------------------------"
    echo
    else

   # Set Setting if the node go downwith panel
    echo "数据库IP"
    read -p "(v2ray_mysqlhost :" v2ray_mysqlhost
    [ -z "${v2ray_mysqlhost}" ] && v2ray_mysqlhost=""
    echo
    echo "---------------------------"
    echo "v2ray_mysqlhost = ${v2ray_mysqlhost}"
    echo "---------------------------"
    echo
    # Set Setting if the node go downwith panel
    echo "数据库端口"
    read -p "(v2ray_mysqlport (Default 3306):" v2ray_mysqlport
    [ -z "${v2ray_mysqlport}" ] && v2ray_mysqlport=3306
    echo
    echo "---------------------------"
    echo "v2ray_mysqlport = ${v2ray_mysqlport}"
    echo "---------------------------"
    echo
    # Set Setting if the node go downwith panel
    echo "数据库用户名"
    read -p "(v2ray_myqluser (Default sspanel):" v2ray_myqluser
    [ -z "${v2ray_myqluser}" ] && v2ray_myqluser="sspanel"
    echo
    echo "---------------------------"
    echo "v2ray_myqluser = ${v2ray_myqluser}"
    echo "---------------------------"
    echo
    # Set Setting if the node go downwith panel
    echo "数据库密码"
    read -p "(v2ray_mysqlpassword (Default password):" v2ray_mysqlpassword
    [ -z "${v2ray_mysqlpassword}" ] && v2ray_mysqlpassword=password
    echo
    echo "---------------------------"
    echo "v2ray_mysqlpassword = ${v2ray_mysqlpassword}"
    echo "---------------------------"
    echo
    # Set Setting if the node go downwith panel
    echo "数据库名"
    read -p "(v2ray_mysqldbname (Default sspanel):" v2ray_mysqldbname
    [ -z "${v2ray_mysqldbname}" ] && v2ray_mysqldbname=sspanel
    echo
    echo "---------------------------"
    echo "v2ray_mysqldbname = ${v2ray_mysqldbname}"
    echo "---------------------------"
    echo
    fi
    # Set sspanel speedtest function
    echo "使用sspanel测试网速"
    read -p "(sspanel 测速: 默认每(6) 小时1次):" sspanel_speedtest
    [ -z "${sspanel_speedtest}" ] && sspanel_speedtest=6
    echo
    echo "---------------------------"
    echo "sspanel_speedtest = ${sspanel_speedtest}"
    echo "---------------------------"
    echo

    # Set V2ray backend API Listen port
    echo "设置V2ray Grpc API侦听端口"
    read -p "(V2ray Grpc API侦听端口(默认 2333):" v2ray_api_port
    [ -z "${v2ray_api_port}" ] && v2ray_api_port=2333
    echo
    echo "---------------------------"
    echo "V2ray Grpc API Listen port = ${v2ray_api_port}"
    echo "---------------------------"
    echo

    # Set Setting if the node go downwith panel
    echo "设置节点是否与面板一起关闭"
    read -p "(v2ray_downWithPanel (默认 0):" v2ray_downWithPanel
    [ -z "${v2ray_downWithPanel}" ] && v2ray_downWithPanel=0
    echo
    echo "---------------------------"
    echo "v2ray_downWithPanel = ${v2ray_downWithPanel}"
    echo "---------------------------"
    echo

    # Set Setting if the node go downwith panel

}

pre_install_caddy(){

    # Set caddy v2ray domain
    echo "caddy v2ray 域名"
    read -p "(没有默认值，请确保输入的内容正确):" v2ray_domain
    [ -z "${v2ray_domain}" ]
    echo
    echo "---------------------------"
    echo "v2ray_domain = ${v2ray_domain}"
    echo "---------------------------"
    echo


    # Set caddy v2ray path
    echo "caddy v2ray 路径"
    read -p "(Default path: /hls/cctv5phd.m3u8):" v2ray_path
    [ -z "${v2ray_path}" ] && v2ray_path="/hls/cctv5phd.m3u8"
    echo
    echo "---------------------------"
    echo "v2ray_path = ${v2ray_path}"
    echo "---------------------------"
    echo

    # Set caddy v2ray tls email
    echo "caddy v2ray tls email"
    read -p "(没有默认值，请确保输入的内容正确 ):" v2ray_email
    [ -z "${v2ray_email}" ]
    echo
    echo "---------------------------"
    echo "v2ray_email = ${v2ray_email}"
    echo "---------------------------"
    echo

    # Set Caddy v2ray listen port
    echo "caddy v2ray 本地监听端口"
    read -p "(Default port: 10550):" v2ray_local_port
    [ -z "${v2ray_local_port}" ] && v2ray_local_port=10550
    echo
    echo "---------------------------"
    echo "v2ray_local_port = ${v2ray_local_port}"
    echo "---------------------------"
    echo

    # Set Caddy  listen port
    echo "caddy 监听端口"
    read -p "(默认: 443):" caddy_listen_port
    [ -z "${caddy_listen_port}" ] && caddy_listen_port=443
    echo
    echo "---------------------------"
    echo "caddy_listen_port = ${caddy_listen_port}"
    echo "---------------------------"
    echo


}

# Config docker
config_docker(){
    echo "按任意键开始…或按Ctrl+C取消"
    char=`get_char`
    cd ${cur_dir}
    echo "安装 curl"
    install_dependencies
    echo "创建 docker-compose.yml"
    cat>docker-compose.yml<<EOF
version: '2'

services:
  v2ray:
    image: ${docker_addresss}
    restart: always
    network_mode: "host"
    extra_hosts:
      auth.rico93.com: 127.0.0.1
    environment:
      sspanel_url: "${sspanel_url}"
      key: "${sspanel_key}"
      speedtest: ${sspanel_speedtest}
      node_id: ${sspanel_node_id}
      api_port: ${v2ray_api_port}
      downWithPanel: ${v2ray_downWithPanel}
      LDNS: "${LDNS}"
      TZ: "Asia/Shanghai"
      MYSQLHOST: ${v2ray_mysqlhost}
      MYSQLDBNAME: ${v2ray_mysqldbname}
      MYSQLUSR: ${v2ray_myqluser}
      MYSQLPASSWD: "${v2ray_mysqlpassword}"
      MYSQLPORT: ${v2ray_mysqlport}
      PANELTYPE: ${v2ray_paneltype}
      usemysql: ${v2ray_usemysql}
      CF_Key: ${cloudflare_key}
      CF_Email: ${cloudflare_email}
      MUREGEX: "${MUREGEX}"
      MUSUFFIX: "${MUSUFFIX}"
      ProxyTCP: ${ProxyTCP}
    volumes:
      - /etc/localtime:/etc/localtime:ro
    logging:
      options:
        max-size: "10m"
        max-file: "3"
EOF
}


# Config caddy_docker
config_caddy_docker(){
    echo "按任意键开始…或按Ctrl+C取消"
    char=`get_char`
    cd ${cur_dir}
    echo "安装 curl"
    install_dependencies
    cat>Caddyfile<<EOF
{\$V2RAY_DOMAIN}:{\$V2RAY_OUTSIDE_PORT}
{
  root /srv/www
  log ./caddy.log
  proxy {\$V2RAY_PATH} 127.0.0.1:{\$V2RAY_PORT} {
    websocket
    header_upstream -Origin
  }
  gzip
  tls {\$V2RAY_EMAIL} {
    protocols tls1.2 tls1.3
    # remove comment if u want to use cloudflare (for DNS challenge authentication)
    # dns cloudflare
  }
  realip cloudflare
}
EOF
    echo "创建 docker-compose.yml"
    cat>docker-compose.yml<<EOF
version: '2'

services:
  v2ray:
    image: ${docker_addresss}
    restart: always
    network_mode: "host"
    extra_hosts:
      auth.rico93.com: 127.0.0.1
    environment:
      sspanel_url: "${sspanel_url}"
      key: "${sspanel_key}"
      speedtest: ${sspanel_speedtest}
      node_id: ${sspanel_node_id}
      api_port: ${v2ray_api_port}
      downWithPanel: ${v2ray_downWithPanel}
      LDNS: "${LDNS}"
      TZ: "Asia/Shanghai"
      MYSQLHOST: ${v2ray_mysqlhost}
      MYSQLDBNAME: ${v2ray_mysqldbname}
      MYSQLUSR: ${v2ray_myqluser}
      MYSQLPASSWD: "${v2ray_mysqlpassword}"
      MYSQLPORT: ${v2ray_mysqlport}
      PANELTYPE: ${v2ray_paneltype}
      usemysql: ${v2ray_usemysql}
      CF_Key: ${cloudflare_key}
      CF_Email: ${cloudflare_email}
      MUREGEX: "${MUREGEX}"
      MUSUFFIX: "${MUSUFFIX}"
      ProxyTCP: ${ProxyTCP}
    volumes:
      - /etc/localtime:/etc/localtime:ro
    logging:
      options:
        max-size: "10m"
        max-file: "3"

  caddy:
    image: hulisang/v2ray_v3:caddy
    restart: always
    environment:
      - ACME_AGREE=true
      #      if u want to use cloudflare (for DNS challenge authentication)
      #      - CLOUDFLARE_EMAIL=xxxxxx@out.look.com
      #      - CLOUDFLARE_API_KEY=xxxxxxx
      - V2RAY_DOMAIN=${v2ray_domain}
      - V2RAY_PATH=${v2ray_path}
      - V2RAY_EMAIL=${v2ray_email}
      - V2RAY_PORT=${v2ray_local_port}
      - V2RAY_OUTSIDE_PORT=${caddy_listen_port}
    network_mode: "host"
    volumes:
      - ./.caddy:/root/.caddy
      - ./Caddyfile:/etc/Caddyfile
      - /etc/localtime:/etc/localtime:ro
EOF
}

# Config caddy_docker
config_caddy_docker_cloudflare(){

    echo "按任意键开始…或按Ctrl+C取消"
    char=`get_char`
    cd ${cur_dir}
    echo "安装 curl first "
    install_dependencies
    echo "开始写入 Caddy 文件和 docker-compose.yml"
    cat>Caddyfile<<EOF
{\$V2RAY_DOMAIN}:{\$V2RAY_OUTSIDE_PORT}
{
  root /srv/www
  log ./caddy.log
  proxy {\$V2RAY_PATH} 127.0.0.1:{\$V2RAY_PORT} {
    websocket
    header_upstream -Origin
  }
  gzip
  tls {\$V2RAY_EMAIL} {
    protocols tls1.2 tls1.3
    # remove comment if u want to use cloudflare (for DNS challenge authentication)
    dns cloudflare
  }
  realip cloudflare
}
EOF
    echo "写入 docker-compose.yml"
    cat>docker-compose.yml<<EOF
version: '2'

services:
  v2ray:
    image: ${docker_addresss}
    restart: always
    network_mode: "host"
    extra_hosts:
      auth.rico93.com: 127.0.0.1
    environment:
      sspanel_url: "${sspanel_url}"
      key: "${sspanel_key}"
      speedtest: ${sspanel_speedtest}
      node_id: ${sspanel_node_id}
      api_port: ${v2ray_api_port}
      downWithPanel: ${v2ray_downWithPanel}
      LDNS: "${LDNS}"
      TZ: "Asia/Shanghai"
      MYSQLHOST: ${v2ray_mysqlhost}
      MYSQLDBNAME: ${v2ray_mysqldbname}
      MYSQLUSR: ${v2ray_myqluser}
      MYSQLPASSWD: "${v2ray_mysqlpassword}"
      MYSQLPORT: ${v2ray_mysqlport}
      PANELTYPE: ${v2ray_paneltype}
      usemysql: ${v2ray_usemysql}
      CF_Key: ${cloudflare_key}
      CF_Email: ${cloudflare_email}
      MUREGEX: "${MUREGEX}"
      MUSUFFIX: "${MUSUFFIX}"
      ProxyTCP: ${ProxyTCP}
    volumes:
      - /etc/localtime:/etc/localtime:ro
    logging:
      options:
        max-size: "10m"
        max-file: "3"

  caddy:
    image: hulisang/v2ray_v3:caddy
    restart: always
    environment:
      - ACME_AGREE=true
      #      if u want to use cloudflare (for DNS challenge authentication)
      - CLOUDFLARE_EMAIL=${cloudflare_email}
      - CLOUDFLARE_API_KEY=${cloudflare_key}
      - V2RAY_DOMAIN=${v2ray_domain}
      - V2RAY_PATH=${v2ray_path}
      - V2RAY_EMAIL=${v2ray_email}
      - V2RAY_PORT=${v2ray_local_port}
      - V2RAY_OUTSIDE_PORT=${caddy_listen_port}
    network_mode: "host"
    volumes:
      - ./.caddy:/root/.caddy
      - ./Caddyfile:/etc/Caddyfile
      - /etc/localtime:/etc/localtime:ro
EOF

}

# Install docker and docker compose
install_docker(){
    echo -e "开始安装 Docker "
    curl -fsSL https://get.docker.com -o get-docker.sh
    bash get-docker.sh
    echo -e "开始安装 Docker Compose "
    curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    curl -L https://raw.githubusercontent.com/docker/compose/1.8.0/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose
    clear
    echo "启动 Docker "
    service docker start
    echo "启动 Docker-Compose "
    docker-compose pull
    docker-compose up -d
    echo
    echo -e "恭喜，V2ray服务器安装完成！"
    echo
    echo "好好享受吧！"
    echo
}

install_check(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        if centosversion 5; then
            return 1
        fi
        return 0
    else
        return 1
    fi
}

install_select(){
    clear
    while true
    do
    echo  "您将选择哪个v2ray Docker："
    for ((i=1;i<=${#software[@]};i++ )); do
        hint="${software[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "请输入一个数字 (默认 ${software[0]}):" selected
    [ -z "${selected}" ] && selected="1"
    case "${selected}" in
        1|2|3|4)
        echo
        echo "你的选择 = ${software[${selected}-1]}"
        echo
        break
        ;;
        *)
        echo -e "[${red}Error${plain}] 请只输入数字 [1-4]"
        ;;
    esac
    done
}
install_dependencies(){
    if check_sys packageManager yum; then
        echo -e "[${green}Info${plain}] 正在检查EPEL存储库。。。"
        if [ ! -f /etc/yum.repos.d/epel.repo ]; then
            yum install -y epel-release > /dev/null 2>&1
        fi
        [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] 安装EPEL存储库失败，请检查。" && exit 1
        [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils > /dev/null 2>&1
        [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel > /dev/null 2>&1
        echo -e "[${green}Info${plain}] Checking the EPEL repository complete..."

        yum_depends=(
             curl
        )
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
    elif check_sys packageManager apt; then
        apt_depends=(
           curl
        )
        apt-get -y update
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
    fi
    echo -e "[${green}Info${plain}] Setting TimeZone to Shanghai"
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"
}
#update_image
update_image_v2ray(){
    echo "关闭当前服务"
    docker-compose down
    echo "拉取 Images"
    docker-compose pull
    echo "启动服务"
    docker-compose up -d
}

#show last 100 line log

logs_v2ray(){
    echo "最后100行日志"
    docker-compose logs --tail 100
}

# Update config
update_config_v2ray(){
    cd ${cur_dir}
    echo "关闭当前服务"
    docker-compose down
    install_select
    case "${selected}" in
        1)
        pre_install_docker_compose
        config_docker
        ;;
        2)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker
        ;;
        3)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker_cloudflare
        ;;
        *)
        echo "错误的号码"
        ;;
    esac

    echo "启动服务"
    docker-compose pull
    docker-compose up -d

}
# remove config
# Install v2ray
install_v2ray(){
    install_select
    case "${selected}" in
        1)
        pre_install_docker_compose
        config_docker
        ;;
        2)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker
        ;;
        3)
        pre_install_docker_compose
        pre_install_caddy
        config_caddy_docker_cloudflare
        ;;
        *)
        echo "错误的号码"
        ;;
    esac
    install_docker
}

# Initialization step
clear
while true
do
echo  "您将选择哪种操作："
for ((i=1;i<=${#operation[@]};i++ )); do
    hint="${operation[$i-1]}"
    echo -e "${green}${i}${plain}) ${hint}"
done
read -p "请输入一个数字 (默认 ${operation[0]}):" selected
[ -z "${selected}" ] && selected="1"
case "${selected}" in
    1|2|3|4)
    echo
    echo "你的选择 = ${operation[${selected}-1]}"
    echo
    ${operation[${selected}-1]}_v2ray
    break
    ;;
    *)
    echo -e "[${red}Error${plain}] 请只输入数字 [1-4]"
    ;;
esac
done
