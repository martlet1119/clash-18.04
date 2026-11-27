#!/usr/bin/env bash
set -euo pipefail

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/clash-verge-noble"
root="$data_dir/root"
profile_home="$data_dir/home"
mkdir -p "$data_dir" "$profile_home"

if [[ ${1:-} == --install ]]; then
  package=$(realpath "${2:?Pass the path to the Clash Verge Rev amd64 deb}")
  if [[ ! -x "$root/usr/bin/apt-get" ]]; then
    release=https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release
    archive=ubuntu-base-24.04.5-base-amd64.tar.gz
    cd "$data_dir"
    curl -fsSLO "$release/$archive"
    curl -fsSLO "$release/SHA256SUMS"
    grep -F "$archive" SHA256SUMS | sha256sum --check -
    mkdir -p "$root"
    tar --no-same-owner -xzf "$archive" -C "$root"
  fi

  bwrap --unshare-user --uid 0 --gid 0 --bind "$root" / \
    --dev /dev --proc /proc --tmpfs /tmp \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind "$package" /tmp/clash-verge.deb \
    --setenv DEBIAN_FRONTEND noninteractive --setenv LANG C.UTF-8 --chdir / \
    /bin/sh -ec 'mkdir -p /usr/local/share/fonts; apt-get -o APT::Sandbox::User=root update && apt-get -o APT::Sandbox::User=root install -y --no-install-recommends /tmp/clash-verge.deb dbus-x11 ca-certificates fonts-noto-cjk libglib2.0-bin gsettings-desktop-schemas dconf-gsettings-backend systemd'
  exit
fi

if [[ ${1:-} == --autostart ]]; then
  "$0" >> "$data_dir/launcher.log" 2>&1 &
  for ((attempt = 0; attempt < 60; attempt++)); do
    if ss -ltnpH 'sport = :7890' | grep -F '127.0.0.1:7890' | grep -q '"verge-mihomo"'; then
      for protocol in http https socks; do
        /usr/bin/gsettings set "org.gnome.system.proxy.$protocol" host '127.0.0.1'
        /usr/bin/gsettings set "org.gnome.system.proxy.$protocol" port 7890
      done
      /usr/bin/gsettings set org.gnome.system.proxy mode manual
      wait
      exit
    fi
    sleep 1
  done
  printf 'Clash Verge did not bind port 7890 within 60 seconds.\n' >> "$data_dir/launcher.log"
  wait
  exit
fi

mkdir -p "$root/home/clash" "$root/run/dbus" "$root/run/systemd/system"
touch "$root/run/dbus/system_bus_socket"
touch "$root/xauthority"
if ! grep -q "^[^:]*:[^:]*:$(id -u):" "$root/etc/passwd"; then
  printf 'clash:x:%s:%s:Clash Verge:/home/clash:/bin/sh\n' "$(id -u)" "$(id -g)" >> "$root/etc/passwd"
fi
authority="${XAUTHORITY:-$HOME/.Xauthority}"
xauth_args=()
if [[ -r "$authority" ]]; then
  xauth_args=(--ro-bind "$authority" /xauthority --setenv XAUTHORITY /xauthority)
fi

exec env -i PATH=/usr/bin:/bin /usr/bin/bwrap --ro-bind "$root" / --dev /dev --proc /proc --tmpfs /tmp \
  --dir /tmp/clash-runtime \
  --ro-bind /run/dbus/system_bus_socket /run/dbus/system_bus_socket \
  --ro-bind /run/systemd/system /run/systemd/system \
  --ro-bind /tmp/.X11-unix /tmp/.X11-unix \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --bind "$profile_home" /home/clash \
  "${xauth_args[@]}" --setenv HOME /home/clash \
  --setenv PATH /usr/bin:/bin --setenv DISPLAY "${DISPLAY:-:0}" \
  --setenv LANG C.UTF-8 --setenv XDG_RUNTIME_DIR /tmp/clash-runtime \
  --setenv GDK_BACKEND x11 --setenv LIBGL_ALWAYS_SOFTWARE 1 \
  --setenv WEBKIT_DISABLE_DMABUF_RENDERER 1 --chdir /home/clash \
  /usr/bin/dbus-run-session -- /usr/bin/clash-verge
