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

  # 1. Deteksi otomatis akselerasi KVM
  # Railway tidak mengekspos /dev/kvm, sehingga otomatis memakai QEMU multi-threaded TCG (KVM=N)
  if [ -z "${KVM:-}" ] || [ "${KVM,,}" = "auto" ]; then
    if [ -e /dev/kvm ] && sh -c 'echo -n > /dev/kvm' >/dev/null 2>&1; then
      export KVM="Y"
    else
      export KVM="N"
    fi
  fi

  # 2. Deteksi otomatis mode jaringan
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

  # 3. Sinkronisasi port Web Viewer (noVNC) dengan $PORT dari Railway HTTP Domain
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
