#!/bin/bash

# ==== SETTINGS ====
ABUSEIPDB_API_KEY="5f760c57d7ffcec04c2ccbb625bd24b85912f0cc1526158f420cc2bec438814705a7d7a6716f8c39"
MAX_AGE=7
LIMIT=100

ABUSEIPDB_URL="https://api.abuseipdb.com/api/v2/blacklist"
AGGRESSIVE_IP_URL="https://raw.githubusercontent.com/duggytuxy/Intelligence_IPv4_Blocklist/refs/heads/main/agressive_ips_dst_fr_be_blocklist.txt"
BAD_UA_URL="https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/_generator_lists/bad-user-agents.list"

CF_IPV4_URL="https://www.cloudflare.com/ips-v4"
CF_IPV6_URL="https://www.cloudflare.com/ips-v6"

# ==== DIRECTORIES ====
HAPROXY_DIR="/etc/haproxy"
TMP_DIR="/tmp/haproxy_updates"
mkdir -p "$TMP_DIR"

# ==== 1. Fetch new IPs ====
echo "[*] Fetching IPs from AbuseIPDB..."
curl -sG "$ABUSEIPDB_URL" \
  --data-urlencode "confidenceMinimum=90" \
  --data-urlencode "limit=$LIMIT" \
  --data-urlencode "maxAgeInDays=$MAX_AGE" \
  -H "Key: $ABUSEIPDB_API_KEY" \
  -H "Accept: application/json" | \
  jq -r '.data[].ipAddress' > "$TMP_DIR/ip_abuseipdb.lst"

echo "[*] Fetching aggressive IPs from GitHub..."
curl -s "$AGGRESSIVE_IP_URL" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' > "$TMP_DIR/ip_github.lst"

# ==== 2. Combine with existing banned.lst ====
echo "[*] Merging with existing banned.lst..."
cat "$TMP_DIR/ip_abuseipdb.lst" "$TMP_DIR/ip_github.lst" "$HAPROXY_DIR/banned.lst" 2>/dev/null | sort -u > "$TMP_DIR/banned.lst"

# ==== 3. Update Bad User Agents ====
echo "[*] Fetching bad user-agents..."
curl -s "$BAD_UA_URL" | grep -vE '^#|^\s*$' > "$TMP_DIR/bad_ua.lst"

# ==== 4. Fetch Cloudflare IPs ====
echo "[*] Fetching Cloudflare IPs..."
curl -s "$CF_IPV4_URL" > "$TMP_DIR/cloudflare-ips-v4.lst"
curl -s "$CF_IPV6_URL" > "$TMP_DIR/cloudflare-ips-v6.lst"

# ==== 5. Move to HAProxy directory ====
mv "$TMP_DIR/banned.lst" "$HAPROXY_DIR/banned.lst"
mv "$TMP_DIR/bad_ua.lst" "$HAPROXY_DIR/bad_ua.lst"
mv "$TMP_DIR/cloudflare-ips-v4.lst" "$HAPROXY_DIR/cloudflare-ips-v4.lst"
mv "$TMP_DIR/cloudflare-ips-v6.lst" "$HAPROXY_DIR/cloudflare-ips-v6.lst"

# ==== 6. Reload HAProxy ====
echo "[*] Reloading HAProxy..."
systemctl reload haproxy

echo "[✓] HAProxy lists updated and reloaded."
