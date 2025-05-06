#!/bin/bash
echo "=== VALIDATOR TUNING SERVER SANTRICYBER ==="

# 1. Check ulimit
echo -n "[+] Ulimit nofile: "
ulimit -n

# 2. Check systemd limit
echo -n "[+] Systemd system.conf NOFILE: "
grep -E '^DefaultLimitNOFILE=' /etc/systemd/system.conf || echo "❌ Belum diset"

# 3. Check HAProxy maxconn
echo -n "[+] HAProxy maxconn: "
grep -E 'maxconn' /etc/haproxy/haproxy.cfg | grep -v '#' || echo "❌ Belum diset"

# 4. Check sysctl.conf
echo -n "[+] Sysctl somaxconn: "
sysctl net.core.somaxconn

echo -n "[+] Sysctl netdev_max_backlog: "
sysctl net.core.netdev_max_backlog

echo -n "[+] Sysctl tcp_max_syn_backlog: "
sysctl net.ipv4.tcp_max_syn_backlog

# 5. Check worker connections in nginx
echo -n "[+] NGINX worker_connections: "
grep -E 'worker_connections' /etc/nginx/nginx.conf || echo "❌ Belum diset"

echo -e "\n=== VALIDASI SELESAI ==="