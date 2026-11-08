#!/usr/bin/env bash
# Startup hook untuk menjalankan OS Windows XP Professional SP3 (QEMU) di Railway.
# File ini otomatis di-source oleh /run/entry.sh sebelum inisialisasi VM & jaringan.

if [ "${RAILWAY_XP_HOOK_DONE:-0}" != "1" ]; then
  export RAILWAY_XP_HOOK_DONE="1"

  # Pastikan direktori storage dan shared memory tersedia
  mkdir -p "${STORAGE:-/storage}" /dev/shm 2>/dev/null || true

  # Jaga koneksi TCP tetap responsif tanpa melambat saat idle (diabaikan jika host memblokir sysctl)
  sysctl -w net.ipv4.tcp_keepalive_time=30 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_keepalive_intvl=10 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_keepalive_probes=6 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true

  # 1. Auto-sizing RAM berdasarkan batas cgroup container Railway (mencegah error "0 bytes" & OOM Kill)
  # Nonaktifkan RAM_CHECK bawaan karena cgroup memory.current menghitung file page-cache saat ekstrak ISO 600MB.
  export RAM_CHECK="N"

  _mem_limit_bytes=""
  if [ -r /sys/fs/cgroup/memory.max ]; then
    _raw_max=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)
    if [[ "$_raw_max" =~ ^[0-9]+$ ]] && [ "${#_raw_max}" -lt 18 ]; then
      _mem_limit_bytes="$_raw_max"
    fi
    unset _raw_max
  elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    _raw_max=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || true)
    if [[ "$_raw_max" =~ ^[0-9]+$ ]] && [ "${#_raw_max}" -lt 18 ]; then
      _mem_limit_bytes="$_raw_max"
    fi
    unset _raw_max
  fi

  if [ -z "$_mem_limit_bytes" ]; then
    _mem_limit_bytes=$(free -b 2>/dev/null | awk '/^Mem:/ {print $2; exit}' || echo "1073741824")
  fi

  _limit_mb=$(( _mem_limit_bytes / 1048576 ))

  if [ -z "${RAM_SIZE:-}" ] || [ "${RAM_SIZE,,}" = "auto" ]; then
    if [ "$_limit_mb" -le 600 ]; then
      # Container <= 512 MB (misal Railway Trial Plan): XP SP3 tetap lancar di 256 MB + hemat overhead
      export RAM_SIZE="256M"
      : "${TCG_TB_SIZE:="64"}"
      : "${SAMBA:="N"}"
      export TCG_TB_SIZE SAMBA
    elif [ "$_limit_mb" -le 1150 ]; then
      # Container ~1 GB
      export RAM_SIZE="512M"
      : "${TCG_TB_SIZE:="128"}"
      export TCG_TB_SIZE
    elif [ "$_limit_mb" -le 2200 ]; then
      # Container ~2 GB
      export RAM_SIZE="1024M"
      : "${TCG_TB_SIZE:="256"}"
      export TCG_TB_SIZE
    else
      # Container >= 4 GB (Railway Hobby / Pro)
      export RAM_SIZE="1536M"
      : "${TCG_TB_SIZE:="256"}"
      export TCG_TB_SIZE
    fi
  else
    # Jika user mengisi RAM_SIZE manual (misal 1G di container 512MB), jaga agar tidak melebihi batas cgroup
    _wanted_bytes=$(numfmt --from=iec "${RAM_SIZE^^}" 2>/dev/null || echo "0")
    if [ "$_wanted_bytes" -gt 0 ]; then
      _wanted_mb=$(( _wanted_bytes / 1048576 ))
      _safe_max_mb=$(( _limit_mb - 180 ))
      [ "$_safe_max_mb" -lt 192 ] && _safe_max_mb=192
      if [ "$_wanted_mb" -gt "$_safe_max_mb" ]; then
        export RAM_SIZE="${_safe_max_mb}M"
      fi
      unset _wanted_mb _safe_max_mb
    fi
    unset _wanted_bytes
    : "${TCG_TB_SIZE:="128"}"
    export TCG_TB_SIZE
  fi
  unset _mem_limit_bytes _limit_mb

  # 2. Deteksi otomatis akselerasi KVM
  # Railway tidak mengekspos /dev/kvm, sehingga otomatis memakai QEMU multi-threaded TCG (KVM=N)
  if [ -z "${KVM:-}" ] || [ "${KVM,,}" = "auto" ]; then
    if [ -e /dev/kvm ] && sh -c 'echo -n > /dev/kvm' >/dev/null 2>&1; then
      export KVM="Y"
    else
      export KVM="N"
    fi
  fi

  # 3. Deteksi otomatis mode jaringan
  # Di Railway (tanpa NET_ADMIN / /dev/net/tun), gunakan user-mode SLIRP yang meneruskan
  # port 3389 (TCP/UDP) container langsung ke Remote Desktop Windows XP.
  if [ -z "${NETWORK:-}" ] || [ "${NETWORK,,}" = "auto" ]; then
    if [ -c /dev/net/tun ] && ip link add rw_probe0 type bridge >/dev/null 2>&1; then
      ip link delete rw_probe0 >/dev/null 2>&1 || true
      export NETWORK="Y"
    else
      export NETWORK="slirp"
    fi
  fi

  if [ "${NETWORK,,}" = "slirp" ] || [ "${NETWORK,,}" = "user" ] || [ "${NETWORK,,}" = "passt" ]; then
    : "${IP:="10.0.2.15"}"
    : "${MASK:="255.255.255.0"}"
    export IP MASK

    # Jika /etc/resolv.conf read-only atau port 53 tidak bisa di-bind tanpa privilege,
    # matikan dnsmasq internal agar QEMU SLIRP menggunakan DHCP/DNS bawaan di user-space (10.0.2.3).
    if [ -z "${DNSMASQ_DISABLE:-}" ]; then
      if [ ! -w /etc/resolv.conf ]; then
        export DNSMASQ_DISABLE="Y"
      else
        _tcp53=0
        _udp53=0
        timeout 0.1 nc -4 -n -d -l 127.0.0.1 53 >/dev/null 2>&1 || _tcp53=$?
        timeout 0.1 nc -4 -n -d -u -l 127.0.0.1 53 >/dev/null 2>&1 || _udp53=$?
        if [ "$_tcp53" -ne 124 ] || [ "$_udp53" -ne 124 ]; then
          export DNSMASQ_DISABLE="Y"
        fi
        unset _tcp53 _udp53
      fi
    fi
  fi

  # 4. Sinkronisasi port Web Viewer (noVNC) dengan $PORT dari Railway HTTP Domain
  # Jangan pernah memakai port 3389 (khusus RDP) atau 5900 (internal QEMU VNC)
  if [ -z "${WEB_PORT:-}" ]; then
    if [ -n "${PORT:-}" ] && [ "${PORT}" != "3389" ] && [ "${PORT}" != "5900" ]; then
      export WEB_PORT="${PORT}"
    else
      export WEB_PORT="8006"
    fi
  fi
fi

# Kembalikan eksekusi ke /run/entry.sh jika di-source, atau jalankan entry.sh jika dipanggil langsung
if (return 0 2>/dev/null); then
  return 0
else
  exec /usr/bin/tini -s /run/entry.sh
fi
