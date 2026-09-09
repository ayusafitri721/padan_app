# Dokumentasi Komprehensif (Frontend & Backend): Halaman Akun / Profil (Pusat Pengaturan & Kendali Warung) - PADAN

---

## 1. Spesifikasi Frontend UI/UX (Antarmuka Pengguna)

Halaman **Akun** (Profil) berfungsi sebagai pusat kendali operasional, manajemen langganan, dan preferensi kecerdasan buatan (*AI Engine*), dirancang bersih dan profesional di atas latar *canvas* krem lembut (`#F9F6F0`).

### A. Komponen & Struktur Layout Layar

* **Top Bar & Header:**
* Label halaman **"Akun"** dengan logo PADAN, lengkap dengan tombol notifikasi (*bell*) dan avatar profil.


* **Kartu Identitas Pemilik & Warung:**
* Foto avatar profil besar dengan lencana verifikasi hijau.
* Nama Pemilik: **Bu Siti Rahayu**, Nama Usaha: **Warung Bu Siti Sambel Mantap**, dan Jabatan: *Pemilik & Penanggung Jawab Pangan*.
* Badge khusus: **"Mitra Juara Nol-Mubazir ⭐"**.
* Grid statistik ringkas (3 kolom): *Konsistensi (184 Hari Aktif Selaras)*, *Pangan Terjaga (4.280 Porsi Berkah)*, dan *Skor Dapur (4.9/5 Sangat Efisien)*.


* **Kartu Lisensi PADAN Pro Plan:**
* Kontainer latar hijau sage tua (`#3A5A40`) dengan status **"Aktif s/d 14 Des 2025"** (*Lisensi Gerai Terpadu*).
* Fitur terintegrasi: *AI BMKG Weather Spoilage Sync (Otomatis)*, *Dynamic Markdown Pricing Kasir Otomatis*, dan *WhatsApp Broadcast Promo Warga Sekitar*.
* Dua tombol aksi di dalam kartu: **"Kelola Langganan"** (berwarna putih) dan **"Tambah Staf"** (berwarna transparan tonal).


* **Sertifikasi Bebas Mubazir Emas:**
* Kartu informasi sertifikasi resmi dari *Dinas Lingkungan Hidup & Ketahanan Pangan DKI Jakarta* (Berlaku hingga 2026), lengkap dengan tombol aksi **"Unduh PDF"**.


* **Bagian: Operasional & Kasir Warung** (Kendali shift harian, lokasi saji, dan pelaporan):
1. *Profil Outlet & Jam Layanan* (Jl. Tebet Raya No. 42 • Buka 09:00 - 22:00)
2. *Akses Kasir & Shift* (2 Aktif: Dini Shift Pagi, Rian Shift Sore • PIN Akses)
3. *Notifikasi Rekap WhatsApp* (Terhubung 0812-3456-7890)


* **Bagian: Preferensi Mesin AI PADAN** (Pengaturan kalkulasi otomatis pencegahan pembusukan):
* *Sensitivitas Cuaca BMKG:* Pilihan mode **Moderat (Rekomendasi)** vs *Agresif (Musim Hujan)* untuk menyesuaikan taktik olahan sambal dan lauk basah saat radar mendeteksi potensi hujan lebat di area Tebet.
* *Batas Diskon Jam Kritias:* Slider batas maksimal diskon di angka **35%** (rentang *Hemat Modal 15%* hingga *Obral Habis 60%*).
* *Sinkronisasi Kasir Offline:* Informasi status sinkron terakhir dan tombol **"Sinkron"**.


* **Bagian: Pusat Bantuan & Edukasi:**
1. *Konsultasi Pangan PADAN* (Konsultasi resep olahan sisa & kendala POS)
2. *Panduan SOP Kasir & Sisa Bahan* (Standar penyimpanan higienis cold-chain UMKM)
3. *Keluar dari Sesi Kasir* (Tombol merah destruktif: *"Kunci terminal kasir sebelum pergantian shift"*).


* **Footer Status Sistem:**
* Indikator titik hijau: *Terminal POS Terenkripsi Lokal & Cloud*, disertai versi sistem (*PADAN Enterprise System v2.4.2*).


* **Bottom Navigation Bar:**
* Menggunakan animasi tab navigasi interaktif (*floating bubble notch*), dengan tab **Akun** dalam kondisi aktif di posisi paling kanan.



---

## 2. Spesifikasi Backend & Logika Sistem (Backend Architecture)

Backend pada halaman Akun mengelola data relasional profil pengguna, pengaturan waktu operasional (yang berdampak langsung pada algoritma *Dynamic Pricing*), manajemen lisensi langganan, serta konfigurasi parameter sensitivitas AI.

### A. Struktur Skema Basis Data Pendukung pada MariaDB (`padan_db`)

1. **Tabel `outlets` (Profil Outlet & Jam Layanan):**
* `id` (INT, Primary Key, Auto Increment)
* `user_id` (INT, Foreign Key ke tabel `users`)
* `outlet_name` (VARCHAR)
* `address` (TEXT)
* `opening_time` (TIME)
* `closing_time` (TIME) -> *Digunakan oleh cron job backend untuk memicu skedul Dynamic Pricing secara otomatis.*


2. **Tabel `subscriptions` (Status Lisensi PADAN Pro):**
* `id` (INT, Primary Key, Auto Increment)
* `user_id` (INT, Foreign Key ke tabel `users`)
* `plan_name` (VARCHAR, contoh: "PADAN Pro Plan")
* `status` (VARCHAR, contoh: "ACTIVE")
* `expires_at` (DATETIME)


3. **Tabel `ai_preferences` (Preferensi Mesin AI & Sensitivitas):**
* `id` (INT, Primary Key, Auto Increment)
* `user_id` (INT, Foreign Key ke tabel `users`)
* `weather_sensitivity_mode` (VARCHAR, contoh: "MODERATE" atau "AGGRESSIVE")
* `max_critical_discount` (INT, contoh: 35)
* `last_offline_sync` (TIMESTAMP)



### B. Desain Endpoint API (FastAPI)

1. **Endpoint Ambil Profil & Konfigurasi Pengguna (`GET /api/v1/profile/details`)**
* **Logika Backend:** Menggabungkan data dari tabel `users`, `outlets`, `subscriptions`, dan `ai_preferences` untuk merespons seluruh informasi profil, status sertifikasi, statistik efisiensi, serta preferensi AI ke frontend dalam satu payload JSON terstruktur.


2. **Endpoint Perbarui Preferensi Mesin AI (`PUT /api/v1/profile/ai-preferences`)**
* **Payload Request (JSON):**
```json
{
  "weather_sensitivity_mode": "MODERATE",
  "max_critical_discount": 35
}

```


* **Logika Backend:** Memperbarui parameter sensitivitas cuaca BMKG dan batas maksimum diskon jam kritis pada tabel `ai_preferences`. Parameter ini langsung diterapkan oleh engine backend dalam memproses kalkulasi rekomendasi stok dan jadwal markdown harga harian.


3. **Endpoint Keluar Sesi / Logout (`POST /api/v1/auth/logout`)**
* **Logika Backend:** Menghapus atau mencabut token akses aktif (*JWT Token Revocation*) dari sesi terminal kasir lokal demi keamanan data operasional warung.
