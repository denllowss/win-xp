<div align="center">

# 🪟 RAILWAY WINDOWS XP · FAST RDP EDITION

### Jalankan OS Microsoft Windows XP Professional SP3 Asli di Railway · Akses via RDP & Browser (noVNC)

![Windows XP](https://img.shields.io/badge/OS-Windows_XP_SP3-0078D6?style=for-the-badge&logo=windowsxp&logoColor=white)
![RDP](https://img.shields.io/badge/Access-RDP_3389_%26_Web_noVNC-2284F2?style=for-the-badge)
![Railway](https://img.shields.io/badge/Deploy-Railway-0B0D0E?style=for-the-badge&logo=railway&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Unprivileged_Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)

</div>

---

## ✨ Fitur Utama

| | Fitur | Detail |
|---|---|---|
| 🪟 | **OS Windows XP Asli** | Otomatis mengunduh & menginstal **Windows XP Professional SP3 (x86)** tanpa intervensi manual (*unattended setup*). |
| ☁️ | **Siap jalan di Railway** | Berjalan **tanpa butuh `/dev/kvm`**, `--privileged`, atau `--cap-add NET_ADMIN` (otomatis memakai *multi-threaded QEMU TCG* + *SLIRP user-mode networking*). |
| ⚡ | **Fast RDP (Port 3389)** | Port `3389` diteruskan langsung ke Remote Desktop bawaan Windows XP dengan optimasi registri & TCP. |
| 🌐 | **Web Browser Viewer (noVNC)** | Dilengkapi tampilan web di port `8006` (otomatis mengikuti `$PORT` Railway) lengkap dengan proteksi password untuk memantau proses instalasi dari browser. |
| 🪶 | **Hemat CPU, RAM & Disk** | Disk format `qcow2` *writeback* (awal hanya ~1.5 GB), service berat seperti `wuauserv` (bug 100% CPU `svchost`), *System Restore*, & *Indexing* otomatis dimatikan via `oem/install.bat`. |
| 💾 | **Persistent Storage** | Mendukung **Railway Volume** pada path `/storage` agar instalasi & data Windows XP tidak ter-reset saat *redeploy* / *restart*. |

---

## 🔐 Detail Login Default

| Field | Nilai Default | Keterangan |
|---|---|---|
| **Username** | `root` | Bisa diubah lewat Environment Variable `USERNAME` |
| **Password** | `root` | Bisa diubah lewat Environment Variable `PASSWORD` |
| **Port RDP** | `3389` | Gunakan **Railway TCP Proxy** (target port `3389`) |
| **Port Web (noVNC)** | `8006` / `$PORT` | Gunakan **Railway Public Domain** untuk pantau via browser |

> ⚠️ **Keamanan:** Sebelum digunakan untuk publik, sangat disarankan mengganti `USERNAME` dan `PASSWORD` melalui menu **Variables** di Railway! Password ini melindungi login **RDP** sekaligus login **Web Viewer (noVNC)**.

---

## 📁 Struktur File

```text
win-xp/
├── Dockerfile          # Image berbasis dockurr/windows + patch unprivileged/microVM Railway
├── start.sh            # Startup hook: auto-deteksi KVM, SLIRP networking, DNS, & $PORT
├── oem/
│   └── install.bat     # Optimasi pasca-instalasi otomatis di dalam Windows XP (RDP, Firewall, CPU)
├── railway.json        # Konfigurasi deploy otomatis Railway
├── docker-compose.yml  # Untuk pengujian lokal menggunakan Docker Compose
└── README.md           # Dokumentasi panduan ini
```

---

## 🚂 Cara Deploy di Railway (Step-by-Step)

### 1️⃣ Upload ke GitHub
Upload / push seluruh isi folder ini ke repository GitHub milik Anda.

### 2️⃣ Buat Project di Railway
1. Buka [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo**.
2. Pilih repository GitHub Anda. Railway akan mendeteksi `railway.json` & `Dockerfile` secara otomatis.

### 3️⃣ Tambahkan Volume `/storage` (Sangat Penting!)
Agar Windows XP **tidak menginstal ulang dari awal** setiap kali container restart:
1. Klik kanan pada kanvas project atau buka tab **Volumes** pada service → **Add Volume**.
2. Isi **Mount Path** dengan:
   ```text
   /storage
   ```

### 4️⃣ Atur Networking (Web Viewer + RDP)
Buka **Service → Settings → Networking**:

1. **Public Networking (HTTP Domain — untuk memantau instalasi dari Browser):**
   - Klik **Generate Domain** dan masukkan target port `8006` (jika diminta).
   - Buka link `https://nama-project.up.railway.app` di browser, login dengan `USERNAME` dan `PASSWORD` (`root` / `root`) untuk melihat proses instalasi Windows XP berjalan otomatis!
2. **TCP Proxy (Wajib untuk koneksi Remote Desktop / RDP):**
   - Pada bagian **TCP Proxy**, klik **+ TCP Proxy** dan masukkan target port:
     ```text
     3389
     ```
   - Railway akan memberikan alamat seperti:
     ```text
     monorail.proxy.rlwy.net:12345
     ```

### 5️⃣ Tunggu Instalasi Pertama Selesai
- Saat pertama kali dijalankan (tanpa akselerasi KVM di Railway), proses unduh ISO (~590 MB) dan instalasi otomatis Windows XP SP3 membutuhkan waktu sekitar **10–25 menit** tergantung alokasi CPU Railway.
- Pantau progresnya secara *live* lewat URL **Web Viewer (noVNC)**.
- Setelah masuk ke Desktop Windows XP dan skrip optimasi selesai berjalan, Anda bisa langsung terhubung dengan cepat melalui **RDP**!

---

## 🔌 Cara Connect via RDP

Gunakan alamat **TCP Proxy** dari Railway (contoh: `monorail.proxy.rlwy.net:12345`) **setelah** instalasi Windows XP selesai masuk ke Desktop.

### 🪟 Windows (10 / 11)
1. Tekan `Win + R` → ketik `mstsc` → Enter.
2. Masukkan `monorail.proxy.rlwy.net:12345` pada kolom **Computer**.
3. Klik **Connect**, lalu login dengan Username `root` dan Password `root`.

### 🤖 Android / 🍎 iOS & macOS
1. Install aplikasi **Windows App** (sebelumnya *Microsoft Remote Desktop*).
2. Pilih **Add PC** → masukkan `host:port` dari Railway TCP Proxy.
3. Masukkan akun `root` / `root`.

### 🐧 Linux (FreeRDP / Remmina)
Karena Windows XP menggunakan protokol keamanan klasik RDP (tanpa NLA/CredSSP), tambahkan flag `/sec:rdp` jika memakai `xfreerdp`:
```bash
xfreerdp /v:HOST:PORT /u:root /p:root /sec:rdp /cert:ignore /bpp:16
```
Pada **Remmina**, atur *Security protocol negotiation* ke **RDP** (bukan NLA/TLS).

---

## ⚙️ Kustomisasi Environment Variables (Opsional)

Anda dapat menambahkan variabel berikut di tab **Variables** Railway:

| Variable | Default | Penjelasan |
|---|---|---|
| `USERNAME` | `root` | Nama user Administrator Windows XP & Web Viewer |
| `PASSWORD` | `root` | Password login RDP & Web Viewer |
| `RAM_SIZE` | `1G` | Alokasi RAM untuk Windows XP (`512M`, `1G`, `2G`) |
| `CPU_CORES` | `2` | Jumlah core CPU virtual (`1`, `2`, `4`) |
| `DISK_SIZE` | `16G` | Ukuran maksimum disk virtual `qcow2` |
| `WIDTH` | `1024` | Resolusi lebar layar awal |
| `HEIGHT` | `768` | Resolusi tinggi layar awal |
| `PROTECT` | `Y` | Set `N` jika ingin mematikan password pada halaman Web noVNC |

---

## 🐳 Menjalankan di Docker Lokal

```bash
docker compose up -d --build
```
- **Web Viewer (noVNC):** `http://localhost:8006`
- **RDP:** `localhost:3389` (`root` / `root`)
*(Jika dijalankan di PC/VPS Linux lokal yang memiliki `/dev/kvm`, tambahkan `devices: - /dev/kvm` pada `docker-compose.yml` maka `start.sh` otomatis mengaktifkan akselerasi hardware KVM!)*

---

## 🛠️ Troubleshooting

| Masalah | Solusi |
|---|---|
| RDP belum bisa connect saat baru deploy | Tunggu hingga instalasi otomatis Windows XP selesai sampai muncul Desktop (pantau lewat link HTTP Web Viewer / noVNC). |
| Klien RDP Linux menolak koneksi (NLA/TLS error) | Windows XP SP3 memakai *Classic RDP Security*. Gunakan `/sec:rdp` di FreeRDP atau pilih *Security: RDP* di Remmina. |
| Windows XP ter-install ulang saat restart | Pastikan Anda sudah memasang **Railway Volume** dengan mount path `/storage`. |
| Build / Boot lambat | Tingkatkan alokasi vCPU di pengaturan plan Railway (minimal 2 vCPU sangat membantu emulasi QEMU TCG). |
