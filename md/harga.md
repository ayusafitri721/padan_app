# Dokumentasi Komprehensif (Frontend & Backend): Halaman Harga (Dynamic Pricing Engine) - PADAN

---

## 1. Spesifikasi Frontend UI/UX (Antarmuka Pengguna)

Halaman **Harga** menampilkan pusat kendali untuk fitur **Dynamic Pricing Engine**, yang dirancang untuk mengotomatisasi penurunan harga bertahap menjelang tutup warung guna mencegah sisa pangan menjadi limbah tak terserap.

### A. Komponen & Struktur Layout Layar

* **Top Bar & Header:**
* Menampilkan logo PADAN dan label halaman **"Harga"**, dilengkapi ikon notifikasi dan avatar profil.
* Kartu pengantar fitur: Judul **Dynamic Pricing Engine** dengan badge status hijau lembut **"AI Auto-Markdown"**, serta sub-teks: *"Pencegahan sisa pangan otomatis dengan diskon bertahap menjelang tutup warung."*


* **Toggle Pengaktifan Utama (`Dynamic Pricing Otomatis`):**
* Kartu modul berisi teks keterangan: *"Berjalan otomatis berdasarkan waktu & sisa stok"* dengan chip status **AKTIF**.
* Tombol *Switch* interaktif di sisi kanan.
* Kotak informasi tambahan (berlatar kontras lembut dengan ikon lampu): *"Sistem akan secara otomatis menerapkan potongan harga pada menu yang masih tersisa > 3 porsi."*


* **Timeline Jadwal Markdown Bertahap:**
* Header bagian: **Jadwal Markdown Bertahap** dengan badge **"15-30 Menit Loop"**.
* Tampilan linimasa (*timeline*) vertikal yang menunjukkan siklus intervensi menjelang tutup warung:
1. *20:30 WIB:* Diskon 10% (Pemanasan jam santai).
2. *21:00 WIB:* Diskon 20% (Jam kritis 1 jam sebelum tutup).
3. *21:30 WIB:* Diskon 35% (Flash Promo Anti-Mubazir).
4. *22:00 WIB:* Tutup Warung (Status: *Sisa 0 Porsi*).




* **Parameter Konfigurasi (Edit Aturan):**
* Dilengkapi ikon pengaturan di sudut kanan atas kartu.
* **Slider Batas Maksimum Diskon:** Menampilkan angka besar **35%**, dengan rentang slider interaktif (Min: 10%, Standar: 30-40%, Max: 60%).
* **Jam Mulai Intervensi:** Pengaturan waktu awal (misal: *20:30 WIB*) lengkap dengan tombol interaktif **"Ubah"**.
* **Integrasi Notifikasi Pelanggan:** Kotak centang (*checkbox*) untuk fitur *"Kirim notifikasi broadcast WhatsApp ke pelanggan setia terdekat saat promo anti-mubazir aktif."*


* **Pratinjau Katalog Konsumen (`Live Preview`):**
* Menampilkan simulasi tampilan menu di sisi pembeli saat diskon aktif (contoh: menu *Nasi Goreng Spesial* dengan coretan harga normal *Rp25.000* menjadi harga diskon **Rp16.250**, lengkap dengan informasi sisa 4 porsi).


* **Tombol Aksi Utama (CTA):**
* Tombol berbentuk pil penuh (*pill-shaped*) berwarna hijau sage (`#3A5A40`) bertuliskan ikon dokumen dan teks **"Simpan Konfigurasi Harga"**.
* Catatan bawah kecil: *"Algoritma PADAN akan mengkalibrasi harga sesuai sisa stok aktual di tab 'Stok'."*


* **Bottom Navigation Bar:**
* Docked di bagian bawah layar dengan 5 item: **Beranda**, **Stok**, **Limbah**, **Harga** (dalam kondisi aktif terbungkus pill hijau `#E8F0EA`), dan **Akun**.



---

## 2. Spesifikasi Backend & Logika Sistem (Backend Architecture)

Sistem backend memantau data sisa stok secara *real-time* dan mengeksekusi aturan diskon secara otomatis berdasarkan waktu serta kondisi sisa stok menjelang tutup warung.

### A. Alur Logika Proses (*Dynamic Pricing Execution*)

1. **Pemantauan Sisa Stok Real-Time:** Sistem terus mencocokkan target produksi dengan jumlah porsi yang terjual dari modul *Input Penjualan*.
2. **Evaluasi Syarat Otomatis:** Sistem memeriksa dua kondisi bersamaan menjelang tutup warung:
* Apakah waktu sudah mendekati jam tutup (misalnya 2–3 jam sebelum tutup)?
* Apakah sisa stok masih signifikan (> 3 porsi atau > 20-30% dari target awal)?


3. **Eksekusi Penurunan Harga Bertahap:** Jika syarat terpenuhi dan toggle aktif, sistem menjalankan aturan jadwal markdown secara otomatis (misal: diskon 10% → 20% → 35% tiap interval waktu tertentu).
4. **Pencatatan Hasil Akhir:** Setiap transaksi yang terjadi pada harga diskon dicatat kembali sebagai item "terjual", yang kemudian digunakan oleh halaman *Limbah* untuk menghitung nilai porsi yang berhasil diselamatkan dari pemborosan.

### B. Struktur Tabel Terkait pada MariaDB (`padan_db`)

1. **Tabel `dynamic_pricing_rules` (Pengaturan Aturan Diskon):**
* `id` (INT, Primary Key, Auto Increment)
* `user_id` (INT, Foreign Key ke tabel `users`)
* `is_enabled` (BOOLEAN, status aktif/non-aktif toggle)
* `max_discount_percentage` (INT)
* `start_intervention_time` (TIME)
* `broadcast_whatsapp` (BOOLEAN)


2. **Tabel `pricing_schedules` (Jadwal Siklus Diskon):**
* `id` (INT, Primary Key, Auto Increment)
* `rule_id` (INT, Foreign Key ke tabel `dynamic_pricing_rules`)
* `time_interval` (TIME)
* `discount_percentage` (INT)
* `description` (VARCHAR)



### C. Desain Endpoint API (FastAPI)

1. **Endpoint Simpan Konfigurasi Harga (`PUT /api/v1/pricing/config`)**
* **Payload Request (JSON):**
```json
{
  "is_enabled": true,
  "max_discount_percentage": 35,
  "start_intervention_time": "20:30:00",
  "broadcast_whatsapp": true
}

```


* **Logika Backend:**
* Memperbarui parameter aturan diskon otomatis milik pengguna ke dalam tabel `dynamic_pricing_rules`.
* Mengatur ulang cron job / task scheduler di backend untuk mengevaluasi waktu diskon bertahap sesuai jadwal baru.




2. **Endpoint Cek Status & Pratinjau Diskon Aktif (`GET /api/v1/pricing/live-preview`)**
* **Logika Backend:**
* Memindai sisa stok aktual secara *real-time* dari data penjualan.
* Menghitung harga diskon terkini berdasarkan waktu sistem saat ini terhadap jadwal markdown, lalu merespons data pratinjau katalog untuk dirender pada UI frontend.
