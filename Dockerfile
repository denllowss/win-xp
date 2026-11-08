FROM dockurr/windows:latest

# Patch network.sh agar kompatibel dengan runtime container/microVM unprivileged Railway:
# Pada beberapa cloud microVM (misal interface eth0 memakai virtio_net / PCI bus),
# fungsi validateAdapter() bawaan akan keluar dengan error host-mode kecuali dilewati saat mode user/slirp aktif.
RUN if [ -f /run/network.sh ]; then \
      sed -i '/^validateAdapter()[[:space:]]*{/a \  isUserMode && return 0' /run/network.sh; \
    fi && \
    mkdir -p /storage /oem

# Skrip optimasi otomatis Windows XP saat pertama kali boot (Fast RDP, Firewall, hemat CPU & RAM)
COPY oem/install.bat /oem/install.bat

# Startup hook Railway: deteksi otomatis KVM, SLIRP port-forwarding 3389, DNS, & dynamic $PORT
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
ENV RAM_SIZE="1G"
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
