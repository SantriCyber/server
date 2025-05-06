# 📘 Dokumentasi Lengkap Server SantriCyber

Dokumen ini berisi setup lengkap server produksi untuk SantriCyber, termasuk konfigurasi Cloudflare, HAProxy, NGINX, Fail2Ban, serta tuning sistem agar tahan terhadap serangan hingga 100.000 RPS. Ditujukan untuk menjaga keamanan, kinerja, dan stabilitas layanan komunitas.

---

## 🔁 Arsitektur Umum

```txt
Internet
  ↓
Cloudflare (WAF, DDoS Filter, Rate Limiting)
  ↓
Cloudflared Tunnel (non-public IP, DNS proxy)
  ↓
NGINX (Port 80) → Proxy ke HAProxy
  ↓
HAProxy (Port 31337) → Validasi & Filter
  ↓
Docker Discourse (Port 41111)
```

---

## 🔐 Cloudflare

* Aktifkan fitur:

  * Bot Fight Mode
  * Rate Limiting (77 RPS)
  * 5 Custom WAF Rules
  * Challenge ASN, negara tertentu, bot AI

* Tunnel via Cloudflared langsung ke `localhost`

> Tidak ada IP publik yang terbuka. Server hanya bisa diakses via Tunnel.

---

## 🌀 Cloudflared Tunnel

Konfigurasi dilakukan via Dashboard Cloudflare. Tidak perlu file `config.yml` lokal. Tunnel masuk ke `localhost:80` (NGINX).

---

## 🌐 NGINX Configuration

**Lokasi:** `/etc/nginx/nginx.conf`

Berfungsi sebagai:

* Entry point tunnel
* Proxy ke HAProxy
* Fallback jika HAProxy down

```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;

# Event Loop
events {
    worker_connections 65535;
    multi_accept on;
    accept_mutex off;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 15;
    client_body_timeout 5s;
    client_header_timeout 5s;
    send_timeout 5s;

    gzip on;
    gzip_disable "msie6";

    access_log off;
    error_log /var/log/nginx/error.log crit;

    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    client_max_body_size 10M;

    server {
        listen 80 default_server;
        server_name _;
        server_tokens off;

        location ~* \.(php|sh|py|cgi|exe)$ { return 444; }
        if ($request_method !~ ^(GET|POST|HEAD)$ ) { return 444; }

        location / {
            proxy_pass http://127.0.0.1:31337;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            error_page 502 503 504 = @fallback;
        }

        location @fallback {
            root /var/www/html;
            try_files /index.html =444;
        }
    }
}
```

---

## 🧠 HAProxy Configuration

**Lokasi:** `/etc/haproxy/haproxy.cfg`

Berfungsi sebagai layer utama penyaring trafik:

* Validasi Host
* Blok IP dan User-Agent
* Rate limit per path
* Fallback ke dummy NGINX jika backend mati

(Lihat file penuh di bagian terpisah karena terlalu panjang)

---

## ✅ Whitelist Path

**Lokasi:** `/etc/haproxy/safe_path.lst`

> Daftar path aman yang tidak akan diblok meski rate tinggi.
> Contoh:

```
/login
/logout
/admin
/assets
/robots.txt
/service-worker.js
...dan banyak lainnya
```

---

## 🧱 Fail2Ban Configuration

**Lokasi:** `/etc/fail2ban/jail.local`

```ini
[DEFAULT]
bantime = 7d
findtime = 60s
maxretry = 5
backend = systemd
banaction = iptables-multiport

[sshd]
enabled = true

[haproxy-abuse]
enabled = true
logpath = /var/log/haproxy.log

[haproxy-ddos]
enabled = true
logpath = /var/log/haproxy.log
bantime = 6000

[permanent-ban]
enabled = true
logpath = /etc/haproxy/banned.lst
bantime = -1
action = haproxy-banlist
```

**Filter & Action Files:**

* `haproxy-ddos.conf`: blokir IP yang trigger 429
* `haproxy-abuse.conf`: blokir IP 4xx spammer
* `haproxy-banlist.conf`: auto append ke `banned.lst`

---

## 🔄 Auto Blacklist & User-Agent Updater

**File:** `/etc/haproxy/updatelist_haproxy.sh`

Fungsi:

* Tarik IP dari AbuseIPDB, GitHub
* Tarik User-Agent buruk
* Update Cloudflare IPs
* Reload HAProxy otomatis

```bash
# Jalankan otomatis via cron:
0 * * * * /etc/haproxy/updatelist_haproxy.sh
```

---

## 🔧 OS Tuning (sysctl.conf, limits.conf, systemd)

### `/etc/sysctl.conf`

> Proteksi TCP, ICMP, memory, DDoS, spoofing

```conf
net.core.somaxconn = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.core.netdev_max_backlog = 65536
fs.file-max = 1000000
... (dan lainnya)
```

### `/etc/security/limits.conf`

```conf
* soft nofile 1048576
* hard nofile 1048576
```

### `/etc/systemd/system.conf` dan `user.conf`

```ini
DefaultLimitNOFILE=1048576
```

Aktifkan dengan:

```bash
systemctl daemon-reexec
systemctl restart haproxy nginx cloudflared
```

---

## 🛡️ Auto Cloudflare Under Attack Mode

**File:** `cloudflare_ddos.py`

* Cek CPU usage
* Jika tinggi, aktifkan UAM
* Jika stabil, matikan UAM

### `.env.example`

```ini
CLOUDFLARE_EMAIL=xxx@gmail.com
CLOUDFLARE_API_KEY=xxx
CLOUDFLARE_ZONE_ID=xxx
```

Jalankan terus via systemd atau cron.

---

## ✅ Validator Script

**File:** `/usr/local/bin/validator.sh`

Cek cepat semua konfigurasi sistem:

```bash
#!/bin/bash
ulimit -n
cat /proc/$(pidof haproxy | head -n1)/limits | grep "Max open files"
sysctl net.core.somaxconn
sysctl net.core.netdev_max_backlog
... (dan lainnya)
```

---

## 🧾 Penutup

Setup ini dibuat agar generasi penerus SantriCyber dapat menjalankan infrastruktur forum yang:

* Aman dari serangan
* Stabil hingga puluhan ribu request
* Mudah di-maintain dan terukur

> “Sebaik-baik Santri adalah yang bermanfaat bagi Santri lain dan masyarakat.”
