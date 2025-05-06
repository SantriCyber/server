import requests
import time
import os
from dotenv import load_dotenv

# 🔹 Load konfigurasi dari file .env
load_dotenv()

EMAIL = os.getenv("CLOUDFLARE_EMAIL")
API_KEY = os.getenv("CLOUDFLARE_API_KEY")  # Menggunakan API Key
ZONE_ID = os.getenv("CLOUDFLARE_ZONE_ID")

# 🔹 Variabel Global
THRESHOLD_CPU = 40  # Jika di atas ini, aktifkan Under Attack Mode
DELAY_CHECK = 10  # Cek setiap 60 detik (1 menit)
MINIMUM_UNDER_ATTACK_DURATION = 600  # Jika aktif, minimal 10 menit sebelum menonaktifkan

last_uam_change = 0  # Waktu terakhir Under Attack Mode diaktifkan
under_attack_active = False  # Menyimpan status UAM

# 🔹 Fungsi Mengecek API Cloudflare
def check_cloudflare_connection():
    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}"
    headers = {"X-Auth-Email": EMAIL, "X-Auth-Key": API_KEY, "Content-Type": "application/json"}
    
    response = requests.get(url, headers=headers).json()
    
    if response.get("success"):
        print("✅ Koneksi ke Cloudflare berhasil!")
        return True
    else:
        print(f"❌ Gagal terhubung ke Cloudflare: {response}")
        return False

# 🔹 Fungsi Mengubah Mode "Under Attack"
def set_cloudflare_uam(enable):
    global last_uam_change, under_attack_active

    url = f"https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/settings/security_level"
    security_level = "under_attack" if enable else "high"

    headers = {"X-Auth-Email": EMAIL, "X-Auth-Key": API_KEY, "Content-Type": "application/json"}
    data = {"value": security_level}

    response = requests.patch(url, headers=headers, json=data).json()

    if response.get("success"):
        print(f"✅ Cloudflare mode diubah menjadi: {security_level.upper()}")
        last_uam_change = time.time()  # Simpan waktu perubahan
        under_attack_active = enable  # Update status
    else:
        print(f"❌ Gagal mengubah mode Cloudflare: {response}")

    return response

# 🔹 Fungsi Mendapatkan CPU Usage
def get_cpu_usage():
    total_usage = 0
    for _ in range(3):
        with open("/proc/stat", "r") as f:
            cpu_line = f.readline()
        cpu_stats = [int(x) for x in cpu_line.split()[1:8]]
        idle_time = cpu_stats[3]
        total_time = sum(cpu_stats)

        time.sleep(2)

        with open("/proc/stat", "r") as f:
            cpu_line2 = f.readline()
        cpu_stats2 = [int(x) for x in cpu_line2.split()[1:8]]
        idle_time2 = cpu_stats2[3]
        total_time2 = sum(cpu_stats2)

        usage = 100 * (1 - (idle_time2 - idle_time) / (total_time2 - total_time))
        total_usage += usage

    return round(total_usage / 3, 2)

# 🔹 Fungsi Utama
def main():
    global last_uam_change, under_attack_active

    print("🚀 Monitoring CPU untuk mitigasi DDoS...")

    # 🔍 Cek koneksi ke Cloudflare sebelum menjalankan script
    if not check_cloudflare_connection():
        print("❌ Script dihentikan karena gagal terhubung ke Cloudflare.")
        return

    while True:
        cpu_usage = get_cpu_usage()
        print(f"📊 CPU Usage: {cpu_usage}%")

        # 🔥 Jika CPU tinggi, aktifkan mode "Under Attack"
        if cpu_usage >= THRESHOLD_CPU:
            if not under_attack_active:  # Hanya aktifkan jika belum aktif
                print("⚠️ CPU tinggi! Mengaktifkan 'Under Attack Mode'...")
                set_cloudflare_uam(True)

        # ✅ Jika CPU normal, nonaktifkan "Under Attack" setelah 10 menit
        elif under_attack_active and (time.time() - last_uam_change) > MINIMUM_UNDER_ATTACK_DURATION:
            print("✅ CPU kembali normal, menonaktifkan 'Under Attack Mode'...")
            set_cloudflare_uam(False)

        time.sleep(DELAY_CHECK)

if __name__ == "__main__":
    main()
