#!/usr/bin/env bash
# install-docker.sh — 自动识别 Linux 发行版并安装 Docker (Compose v2)
# 支持国内镜像自动/手动切换，内置错误处理与友好提示。
# ---------------------------------------------------------------
set -Eeuo pipefail

# ────────────────────────── 彩色输出 ────────────────────────── #
info()  { printf "\e[32m[INFO]\e[0m  %s\n" "$*"; }
warn()  { printf "\e[33m[WARN]\e[0m  %s\n" "$*" >&2; }
error() { printf "\e[31m[ERROR]\e[0m %s\n" "$*" >&2; exit 1; }
trap 'error "脚本失败，命令：\"${BASH_COMMAND}\", 退出码 $?"' ERR

need_cmd() { command -v "$1" &>/dev/null; }
as_root()  { ((EUID==0)) && "$@" || sudo "$@"; }

# ─────────── 部署 GeekAI-Plus 函数 ─────────── #
deploy_geekai_plus(){
  local repo=https://gitee.com/blackfox/geekai-plus-open.git
  local dir=${GEEKAI_DIR:-geekai-plus}
  info "部署 GeekAI-Plus 到目录 \"$dir\""
  need_cmd git || error "未找到 git，请检查安装步骤。"
  if [[ -d $dir ]]; then
    warn "目录 $dir 已存在，跳过克隆。"
  else
    git clone --depth 1 "$repo" "$dir"
  fi
  pushd "$dir" >/dev/null
  info "启动 docker compose…"
  if docker compose up -d; then
    info "GeekAI-Plus 部署完成！请访问 http://ip:8080。"
  else
    error "docker compose 启动失败。"
  fi
  popd >/dev/null
}

# ─────────────────── 检测 Docker 是否已安装 ─────────────────── #
if need_cmd docker && (docker compose version &>/dev/null || need_cmd docker-compose); then
  info "Docker 与 Compose 已安装，无需重复操作。"
  deploy_geekai_plus
  exit 0
fi

# ────────────────────────── 解析发行版 ───────────────────────── #
[[ -r /etc/os-release ]] || error "无法识别系统：缺少 /etc/os-release"
. /etc/os-release
OS_ID=${ID,,}
OS_VER=${VERSION_ID:-unknown}
ARCH=$(uname -m)

info "检测到系统：$PRETTY_NAME ($OS_ID $OS_VER, $ARCH)"

# ──────────────────── 镜像域名与自动回退逻辑 ──────────────────── #
# ❶ 用户可通过 DOCKER_MIRROR 指定：
#    - aliyun  → https://mirrors.aliyun.com/docker-ce
#    - tuna    → https://mirrors.tuna.tsinghua.edu.cn/docker-ce
#    - official (默认) → https://download.docker.com
#
# ❷ 若未指定，则先探测官方域名能否连通；失败则自动切换到 aliyun。
#
choose_mirror() {
  local sel=${DOCKER_MIRROR:-auto}

  case "$sel" in
    aliyun)   MIRROR="https://mirrors.aliyun.com/docker-ce" ;;
    tuna)     MIRROR="https://mirrors.tuna.tsinghua.edu.cn/docker-ce" ;;
    official) MIRROR="https://download.docker.com" ;;
    auto)
      MIRROR="https://download.docker.com"
      info "检测官方源连通性…"
      if ! curl -m 3 -sfL "${MIRROR}/linux/${OS_ID}/gpg" -o /dev/null; then
        warn "官方源不可达，回退至阿里云镜像。"
        MIRROR="https://mirrors.aliyun.com/docker-ce"
      fi ;;
    *)
      error "未知镜像标识：$sel（可选 aliyun|tuna|official）" ;;
  esac
  info "使用镜像源：$MIRROR"
}
choose_mirror

# ────────────────────────── 安装函数 ────────────────────────── #
install_docker_debian_like() {
  info "使用 APT 安装 Docker"
  as_root apt-get update -y
  as_root apt-get install -y ca-certificates curl git gnupg lsb-release

  as_root install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "${MIRROR}/linux/${OS_ID}/gpg" \
    | as_root gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    ${MIRROR}/linux/${OS_ID} $(lsb_release -cs) stable" \
    | as_root tee /etc/apt/sources.list.d/docker.list >/dev/null

  as_root apt-get update -y
  as_root apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_docker_centos_like() {
  info "使用 YUM/DNF 安装 Docker"
  local pkgcmd
  if need_cmd dnf; then pkgcmd=dnf; else pkgcmd=yum; fi

  as_root $pkgcmd -y install ${pkgcmd}-plugins-core git
  as_root $pkgcmd config-manager \
    --add-repo "${MIRROR}/linux/centos/docker-ce.repo"
  as_root $pkgcmd -y install \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  as_root systemctl enable --now docker
}

install_docker_fedora() {
  info "使用 DNF 安装 Docker (Fedora)"
  as_root dnf -y install dnf-plugins-core
  as_root dnf config-manager --add-repo \
    "${MIRROR}/linux/fedora/docker-ce.repo"
  as_root dnf -y install \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git
  as_root systemctl enable --now docker
}

install_docker_arch() {
  info "使用 pacman 安装 Docker"
  as_root pacman -Sy --noconfirm docker docker-compose git
  as_root systemctl enable --now docker
}

install_docker_opensuse() {
  info "使用 zypper 安装 Docker"
  as_root zypper -n in docker docker-compose git
  as_root systemctl enable --now docker
}

install_docker_alpine() {
  info "使用 apk 安装 Docker"
  as_root apk add --no-cache docker docker-cli-compose git
  as_root rc-update add docker boot git
  as_root service docker start
}

install_docker_fallback() {
  warn "发行版 \"$OS_ID\" 未做专门适配，执行官方一键脚本…"
  curl -fsSL get.docker.com | as_root sh
}

# ────────────────────────── 分发安装 ────────────────────────── #
case "$OS_ID" in
  debian|ubuntu|linuxmint)    install_docker_debian_like   ;;
  centos|rocky|almalinux|rhel) install_docker_centos_like   ;;
  fedora)                     install_docker_fedora        ;;
  arch|manjaro)               install_docker_arch          ;;
  opensuse*|suse|sles)        install_docker_opensuse      ;;
  alpine)                     install_docker_alpine        ;;
  *)                          install_docker_fallback      ;;
esac

# ──────────────────── 安装后检查 & docker 组 ─────────────────── #
need_cmd docker || error "Docker 安装后仍不可用，请检查日志。"
as_root usermod -aG docker "${SUDO_USER:-$USER}" || true

# ──────────────────── (可选) 镜像加速器配置 ─────────────────── #
if [[ "${ENABLE_REGISTRYMIRROR:-1}" == "1" ]]; then
  as_root mkdir -p /etc/docker
  cat <<-JSON | as_root tee /etc/docker/daemon.json >/dev/null
  {
    "registry-mirrors": [
      "https://registry.docker-cn.com", "https://mirror.ccs.tencentyun.com","https://hub-mirror.c.163.com"
    ]
  }
JSON
  as_root systemctl restart docker
  info "已为 Docker 配置国内镜像加速器。"
fi

# ────────────────────────── 最终信息 ────────────────────────── #
info "Docker 版本：$(docker --version | cut -d',' -f1)"
if docker compose version &>/dev/null; then
  info "Compose 版本：$(docker compose version --short)"
elif need_cmd docker-compose; then
  info "Compose 版本：$(docker-compose --version | awk '{print $3}')"
fi

cat <<'EOF'
╭─────────────────────────────────────────────────────────╮
│ 安装完成！                                              │
│ · 请重新登录或执行 `newgrp docker` 以使用 docker 免 sudo │
│ · 如需跳过镜像加速，可执行：ENABLE_REGISTRYMIRROR=0 ... │
╰─────────────────────────────────────────────────────────╯
EOF

deploy_geekai_plus

