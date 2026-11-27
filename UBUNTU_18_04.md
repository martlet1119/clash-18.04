# 在 Ubuntu 18.04 上运行 Clash Verge Rev 2.5.10

对应机器为 `user-system-product-name`，系统为 Ubuntu 18.04.6 LTS（x86_64）。仓库位于 `/home/user/ybx/clash-verge-rev`。

## 安装方式

Clash Verge Rev 2.5.10 的官方 Linux 包依赖 `libwebkit2gtk-4.1-0` 和 `libayatana-appindicator3-1`。直接在 Ubuntu 18.04 上用 `dpkg -i` 安装会因依赖不足而留下未配置的包。

本仓库的 `scripts/run-on-ubuntu-18.04.sh` 使用 Bubblewrap 在用户目录内建立 Ubuntu 24.04 运行环境，再在其中安装官方 2.5.10 的 DEB 和依赖。正常启动时，应用直接显示在 Ubuntu 18.04 的 X11 桌面上。主程序和内置内核都来自官方 DEB，启动脚本负责挂载运行库、应用数据、X11 和 D-Bus。宿主机的 glibc 无需升级，也无需虚拟机。

| 宿主机目录 | 用途 |
| --- | --- |
| `~/.local/share/clash-verge-noble/root/` | Ubuntu 24.04 运行环境及官方程序 |
| `~/.local/share/clash-verge-noble/home/` | 容器内的应用主目录，保存订阅、设置及日志 |
| `~/.config/autostart/clash-verge-noble.desktop` | GNOME 登录自启项 |

如果设置了 `XDG_DATA_HOME`，脚本会使用其下的 `clash-verge-noble/`。

## 首次安装

在 Ubuntu 18.04 的图形会话里确认 Bubblewrap 可用：

```bash
uname -m
command -v bwrap
bwrap --unshare-user --uid 0 --gid 0 --ro-bind / / /usr/bin/id
```

最后一条命令检查当前用户能否创建独立用户命名空间。如果机器没有安装 Bubblewrap，需要管理员先安装 `bubblewrap`。在应用安装阶段，命名空间内的 UID 0 只用于维护用户目录中的独立文件系统。

从 [官方 v2.5.10 发布页](https://github.com/clash-verge-rev/clash-verge-rev/releases/tag/v2.5.10) 下载 `Clash.Verge_2.5.10_amd64.deb`，例如放到 `~/下载/`。安装并打开：

```bash
cd /home/user/ybx/clash-verge-rev
sha256sum "$HOME/下载/Clash.Verge_2.5.10_amd64.deb"
bash scripts/run-on-ubuntu-18.04.sh --install "$HOME/下载/Clash.Verge_2.5.10_amd64.deb"
bash scripts/run-on-ubuntu-18.04.sh
```

该发布包的 SHA-256 为 `add8564811ba4d2305da443288d23a26c5ed19674b676a0bb58b99ec4f7d13cf`。安装脚本会下载 Ubuntu Base 24.04.5、校验镜像，并在独立环境里安装 WebKitGTK、GTK 托盘库、字体、D-Bus 和 `gsettings` 等组件。运行环境包含 `systemctl`，启动时通过宿主机的系统 D-Bus 查询服务状态。在这台机器上已验证，宿主机没有安装 Clash Verge 服务时，客户端能自动进入 Sidecar 模式。

## 导入订阅和设置端口

1. 打开左侧 **订阅**，在链接栏粘贴服务商提供的订阅地址并导入，使用该订阅。直接导入本地 YAML 时，右键菜单仅提供本地文件操作。需要「更新（代理）」时，把同一订阅录入为远程订阅。
2. 在 **设置 → 端口设置**中，将混合端口设为 `7890`。先用下面的命令检查该端口是否被其他客户端占用。如有占用，在旧客户端里退出或更改其端口。
3. 在代理页选择可用节点。本机使用的订阅显示名为 `Clash_1795787981.yaml`，已验证远程订阅的「更新（代理）」功能。订阅地址和节点凭据保存在应用配置中。

```bash
ss -ltnpH 'sport = :7890'
curl -fsS --max-time 15 -x http://127.0.0.1:7890 -o /dev/null \
  -w 'Google HTTP %{http_code}\n' https://www.google.com/generate_204
```

本机验证时，由 `verge-mihomo` 监听 `127.0.0.1:7890`，通过该端口访问测试地址返回 HTTP 204。

## 登录桌面后自动启动

在宿主机用户 `user` 的终端执行以下命令。仓库路径变化时，将 `Exec=` 改为实际的绝对路径。

```bash
cd /home/user/ybx/clash-verge-rev
chmod +x scripts/run-on-ubuntu-18.04.sh
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/clash-verge-noble.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Clash Verge Rev
Exec=/home/user/ybx/clash-verge-rev/scripts/run-on-ubuntu-18.04.sh --autostart
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
```

GNOME 在登录桌面时执行自启项。脚本启动客户端后最多等待 60 秒，确认 `verge-mihomo` 已监听 `127.0.0.1:7890`，然后将宿主机的 GNOME 网络代理设为 **手动**，HTTP、HTTPS、SOCKS 都指向 `127.0.0.1:7890`。宿主机的局域网代理例外按已有设置处理。

退出当前 Clash Verge 后，可以在终端执行 `./scripts/run-on-ubuntu-18.04.sh --autostart` 验证启动逻辑，或者注销后重新登录验证 GNOME 自启。脚本的日志位于 `~/.local/share/clash-verge-noble/launcher.log`。检查系统代理：

```bash
gsettings get org.gnome.system.proxy mode
for protocol in http https socks; do
  gsettings get "org.gnome.system.proxy.$protocol" host
  gsettings get "org.gnome.system.proxy.$protocol" port
done
```

预期模式为 `'manual'`，三个协议的地址为 `'127.0.0.1'`，端口为 `7890`。如需取消登录自启，移除该 `.desktop` 文件。如需恢复 GNOME 直连，可以执行 `gsettings set org.gnome.system.proxy mode none`。

## 使用范围

手动代理覆盖遵循 GNOME 代理设置的应用。终端程序可按需设置 `http_proxy` 和 `https_proxy`，VS Code 可使用用户设置里的 `http.proxy`。SSH 等程序的流量取决于各自的配置。

TUN 需要宿主机系统服务接管网络流量。本机使用普通用户 Sidecar 模式，TUN 关闭。官方 2.5.10 服务安装器需要 glibc 2.34，而宿主机为 glibc 2.27。界面的「安装服务」无法让当前独立环境接管宿主机的全机流量。
