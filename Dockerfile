FROM dockurr/windows:latest

# Patch skrip internal agar 100% kompatibel dengan container/microVM unprivileged & limit RAM Railway:
# 1. network.sh: lewati cek PCI/veth host-mode saat mode jaringan user/slirp aktif di microVM Railway.
# 2. proc.sh: batasi ukuran cache JIT QEMU TCG (tb-size) agar tidak memicu OOM di container RAM kecil (512MB-1GB).
# 3. utils.sh: kurangi reclaimable page cache (inactive_file + active_file) dari cgroup memory.current
#    agar ekstraksi ISO 600MB tidak membuat deteksi RAM terbaca 0 bytes.
RUN if [ -f /run/network.sh ]; then \
      sed -i '/^validateAdapter()[[:space:]]*{/a \  isUserMode && return 0' /run/network.sh; \
    fi && \
    if [ -f /run/proc.sh ]; then \
      sed -i 's/-accel tcg,thread=multi/-accel tcg,thread=multi,tb-size=${TCG_TB_SIZE:-128}/g' /run/proc.sh; \
    fi && \
    if [ -f /run/utils.sh ]; then \
      sed -i '/current=\$(< \/sys\/fs\/cgroup\/memory\.current)/a \    if [ -r /sys/fs/cgroup/memory.stat ]; then local _pgc; _pgc=$(awk '\''/^(inactive_file|active_file) / {s+=$2} END {print s+0}'\'' /sys/fs/cgroup/memory.stat); if (( current > _pgc )); then current=$(( current - _pgc )); else current=0; fi; fi' /run/utils.sh; \
    fi && \
    mkdir -p /storage /oem

# Skrip optimasi otomatis Windows XP saat pertama kali boot (Fast RDP, Firewall, hemat CPU & RAM)
COPY oem/install.bat /oem/install.bat

# Startup hook Railway: auto-sizing RAM cgroup, KVM, SLIRP port-forwarding 3389, DNS, & dynamic $PORT
COPY start.sh /run/start.sh
COPY start.sh /start.sh

RUN chmod +x /oem/install.bat /run/start.sh /start.sh && \
    (unix2dos /oem/install.bat 2>/dev/null || sed -i 's/\r$//; s/$/\r/' /oem/install.bat)

# Konfigurasi default Windows XP Professional SP3 yang dioptimalkan untuk Railway
ENV VERSION="xp"
ENV STORAGE="/storage"
ENV USERNAME="root"
ENV PASSWORD="root"
ENV AUTOLOGIN="Y"
ENV RAM_SIZE="auto"
ENV RAM_CHECK="N"
ENV CPU_CORES="2"
ENV DISK_SIZE="16G"
ENV DISK_FMT="qcow2"
ENV DISK_CACHE="writeback"
ENV DISK_IO="threads"
ENV ALLOCATE="N"
ENV WIDTH="1024"
ENV HEIGHT="768"
ENV AUDIO="Y"
ENV LOSSY="Y"
ENV PROTECT="Y"

# Catatan: Jangan gunakan instruksi Docker VOLUME di sini karena ditolak oleh Railway builder.
# Pasang Railway Volume dengan mount path /storage melalui dashboard Railway.

# 3389 = Remote Desktop (RDP via Railway TCP Proxy)
# 8006 = Web Viewer noVNC (Akses Browser via Railway Public Domain)
EXPOSE 3389 8006

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
