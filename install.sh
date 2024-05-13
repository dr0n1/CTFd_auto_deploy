#!/bin/bash
# Author: dr0n1
# Version：0.1 beta
# Email: 1930774374@qq.com

[ $(id -u) != "0" ] && {
	echo "请用root用户运行"
	exit 1
}

tm=$(date +'%Y%m%d %T')
COLOR_G="\x1b[0;32m"
COLOR_R="\x1b[0;31m"
RESET="\x1b[0m"

STR="abcdefghijklnmopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

function info() {
	echo -e "${COLOR_G}[$tm] [Info] ${1}${RESET}"
}

function error() {
	echo -e "${COLOR_R}[$tm] [Error] ${1}${RESET}"
}

function generate_password() {
    local password=""
    for ((i=1; i<=12; i++))
    do
        num=$((RANDOM%${#STR}))
        tmp=${STR:num:1}
        password+=$tmp
    done
    echo "$password"
}

function mkdir_directory() {
    read -p "请输入安装路径: " path

    if [ -d "$path" ]; then
        error "目录 $path 已经存在"
        exit 1
    else
        mkdir -p "$path"
    fi

    cd "$path"
}

function install_docker() {
	if command -v docker &>/dev/null; then
        info "docker已安装"
        systemctl restart docker
        if ! docker node ls | grep -q "Leader"; then
            info "Swarm未初始化"
            docker swarm init --advertise-addr 127.0.0.1
            docker node update --label-add='name=linux-1' $(docker node ls -q)
        else
            info "Swarm已经初始化"
        fi
    else
        info "未检测到docker，开始安装 Docker..."
	    ubuntu_version=$(lsb_release -r | awk '{print substr($2,1,2)}')
	    if [ $ubuntu_version -le 16 ]; then
		    apt-get update
		    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
		    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
		    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
		    apt-get update
		    apt-get install -y docker-ce
	    else
		    curl -sSL https://get.daocloud.io/docker | sh
		    if [ $? -ne 0 ]; then
		        curl -fLsS https://get.docker.com/ | sh
		    fi
	    fi

	    if ! command -v docker &>/dev/null; then
		    error "可能由于网络原因或其他未知原因导致Docker安装失败，请检查后重试"
		    exit 1
	    fi

	    systemctl enable docker
	    systemctl restart docker
	    docker swarm init --advertise-addr 127.0.0.1
        docker node update --label-add='name=linux-1' $(docker node ls -q)
	fi
}

function install_dockercompose() {
    if command -v docker-compose &>/dev/null; then
		info "docker-compose已安装"
    else
        info "开始安装docker-compose"
        curl -sSL https://get.daocloud.io/docker | sh
        curl -SL https://github.com/docker/compose/releases/download/v2.4.1/docker-compose-linux-x86_64 -o /usr/bin/docker-compose
        chmod +x /usr/bin/docker-compose
	fi
}

function download_ctfd() {
    retries=3
    count=0

    while [ $count -lt $retries ]; do
        ((count++))
        info "正在进行第 $count 次下载..."
        git clone --depth 1 https://github.com/CTFd/CTFd .
        if [ $? -eq 0 ]; then
            info "ctfd下载成功！"
            return 0
        fi
    done

    error "ctfd下载失败，已达到最大重试次数。"
    exit 1
}

function install_plugins() {
    read -p "是否添加 [ctfd-whale] 插件？(yes/no): " choice1
    choice1=$(echo "$choice1" | tr '[:upper:]' '[:lower:]')
    [ ! -n "${choice1}" ] && { choice1="yes"; }
    if [[ "$choice1" == "yes" || "$choice1" == "y" ]]; then
        install_plugins_whale
    elif [[ "$choice1" == "no" || "$choice1" == "n"  ]]; then
        info "跳过 [ctfd-whale]"
    else
        error "无效的选择"
    fi


    read -p "是否添加 [ctfd-pages-theme] 插件？(yes/no): " choice2
    choice2=$(echo "$choice2" | tr '[:upper:]' '[:lower:]')
    [ ! -n "${choice2}" ] && { choice2="yes"; }
    if [[ "$choice2" == "yes" || "$choice2" == "y" ]]; then
        install_plugins_pages
    elif [[ "$choice2" == "no" || "$choice2" == "n" ]]; then
        info "跳过 [ctfd-pages-theme]"
    else
        error "无效的选择"
    fi
}

function install_plugins_whale() {
    info "开始下载 [ctfd-whale]"
    git clone --depth 1 https://github.com/frankli0324/ctfd-whale CTFd/plugins/ctfd-whale
    echo "flask_apscheduler" >> requirements.txt
    curl -fsSL https://raw.githubusercontent.com/frankli0324/ctfd-whale/master/docker-compose.example.yml -o docker-compose.yml

    info "开始设置参数"
    sed -i "s/=frank/=${pass1}/g" ./docker-compose.yml
    sed -i "s/=qwer/=${pass2}/g" ./docker-compose.yml
    sed -i "s/http:\/\/frpc:7400/http:\/\/${pass1}:${pass2}@frpc:7000/g" ./CTFd/plugins/ctfd-whale/utils/setup.py
    sed -i "s/=your_token/=${pass3}/g" ./docker-compose.yml
    sed -i 's/ctfd_frp-containers/ctfd_containers/g' ./CTFd/plugins/ctfd-whale/utils/docker.py

    read -p "输入你的域名/ip [127.0.0.1.nip.io]:" domain
    [ ! -n "${domain}" ] && { domain="127.0.0.1.nip.io"; }
    sed -i "s/127.0.0.1.nip.io/${domain}/g" ./docker-compose.yml
    sed -i "s/127.0.0.1.nip.io/${domain}/g" ./CTFd/plugins/ctfd-whale/utils/setup.py
    sed -i "s/\"127.0.0.1\"/\"${domain}\"/g" ./CTFd/plugins/ctfd-whale/utils/setup.py
    sed -i "s/\"127.0.0.1\"/\"${domain}\"/g" ./CTFd/plugins/ctfd-whale/utils/routers/frp.py

    read -p "输入http靶机映射端口 [8080]:" httpPort
    [ ! -n "${httpPort}" ] && { httpPort="8080"; }
    sed -i "s/8080:8080/${httpPort}:8080\n      - 10000-10100:10000-10100/g" ./docker-compose.yml
    sed -i "s/8080/${httpPort}/g" ./CTFd/plugins/ctfd-whale/utils/setup.py

    read -p "输入direct模式映射端口范围 [10000-10100]:" directPort
    [ ! -n "${directPort}" ] && { directPort="10000-10100"; }
    sed -i "s/10100/${directPort#*-}/g" ./docker-compose.yml
    sed -i "s/10000/${directPort%-*}/g" ./docker-compose.yml
    sed -i "s/10100/${directPort#*-}/g" ./CTFd/plugins/ctfd-whale/utils/setup.py
    sed -i "s/10000/${directPort%-*}/g" ./CTFd/plugins/ctfd-whale/utils/setup.py
}

function install_plugins_pages() {
    info "开始下载 [ctfd-pages-theme]"
    git clone https://github.com/frankli0324/ctfd-pages-theme CTFd/themes/pages

    info "开始添加路由"
    data=$(cat <<EOM

@challenges_namespace.route("/categories")
class ChallengeCategories(Resource):
    @challenges_namespace.doc(description="Endpoint to get Challenge categories in bulk")
    def get(self):
        chal_q = (Challenges.query.with_entities(Challenges.category).group_by(Challenges.category))
        if not is_admin() or request.args.get("view") != "admin":
            chal_q = chal_q.filter(and_(Challenges.state != "hidden", Challenges.state != "locked"))
        return {"success": True, "data": [i.category for i in chal_q]}
EOM
)

    echo "$data" >> ./CTFd/api/v1/challenges.py
}

function build_ctfd() {
    read -p "web访问ctfd端口 [80]:" port
    [ ! -n "${port}" ] && { port="80"; }
    sed -i "s/- 80:80/- ${port}:80/g" ./docker-compose.yml

    docker-compose build
    docker-compose up -d
}

pass1=$(generate_password)
pass2=$(generate_password)
pass3=$(generate_password)

apt update
apt install -y git
mkdir_directory
install_docker
install_dockercompose
download_ctfd
install_plugins
build_ctfd
