# Dokumentasi Komprehensif (Frontend & Backend): Halaman Limbah (Audit Pangan Berkelanjutan) - PADAN

---

## 1. Spesifikasi Frontend UI/UX (Antarmuka Pengguna)

Halaman **Limbah** dirancang bukan sekadar sebagai laporan rekapitulasi limbah pasif, melainkan sebagai pusat bukti dampak nyata (*impact dashboard*) yang memotivasi pemilik warung melalui visualisasi finansial dan pencapaian keberlanjutan.

### A. Komponen & Struktur Layout Layar

* **Top Bar & Header:**
* Logo aplikasi PADAN dan label halaman **"Limbah"**, dilengkapi ikon notifikasi dan avatar profil.
* Status bar informatif: Badge kiri bertuliskan **"AUDIT PANGAN BERKELANJUTAN"** dengan titik indikator hijau aktif, disandingkan dengan badge kanan bertuliskan **"🌿 Bebas Mubazir Level 3"**.


* **Kartu Utama Dampak Finansial Kumulatif:**
* Kontainer besar dengan latar warna hijau sage tua (`#3A5A40`) bertepi melengkung dan ikon celengan uang di pojok kanan atas.
* Label atas: *DAMPAK FINANSIAL KUMULATIF*.
* Angka utama berukuran besar: **Rp2.500.000** (menunjukkan total kerugian yang berhasil dicegah).
* Dua kartu statistik modular di bagian bawah dalam kontainer utama:
1. *Bulan Ini:* **312 Porsi** (Makanan diselamatkan).
2. *Emisi Tercegah:* **184 kg $CO_2e$** (Penurunan jejak karbon).




* **Grafik Penurunan Limbah (Waste Reduction Chart):**
* Kartu putih bersih dengan tajuk **Grafik Penurunan Limbah** dan sub-teks *Evaluasi berkala 4 bulan terakhir*.
* Dilengkapi badge hijau di kanan atas: **📉 -87% Limbah**.
* **Visualisasi Batang (Bar Chart):** Menampilkan perbandingan volume limbah (dalam kg) secara bulanan:
* Juli: `42 kg`
* Agt: `28 kg`
* Sep: `16 kg`
* Okt: `5.2 kg` (batang disorot penuh dengan warna hijau tua aktif).


* **Kotak Wawasan AI:** Catatan kecil di bawah grafik dengan ikon lampu: *"Porsi over-produksi berkurang drastis berkat kalkulator porsi otomatis BMKG & Hari Libur."*


* **Kartu Profil UMKM & Fitur Pendukung (Dampak & Sertifikasi):**
* **Mini Profil Warung:** Menampilkan foto pemilik warung, nama unit usaha (*Warung Sambel Mantap Bu Siti*), nama lengkap (*Siti Rahmawati*), dan badge hijau *UMKM Mitra*.
* **Banner Langganan:** Kartu info *PADAN Pro Plan* (Aktif s/d 31 Des 2025 • Fitur AI & Cuaca BMKG) dengan tombol panah navigasi.
* **List Menu Aksi & Laporan:**
1. *Laporan Lengkap Food Waste:* Unduh rekap bulanan format PDF (dilengkapi ikon unduh).
2. *Riwayat Audit Pangan Hijau:* 8 kali validasi dapur ramah lingkungan.
3. *Hubungi Konsultan PADAN:* Konsultasi sisa porsi & resep daur pangan (dilengkapi ikon chat).




* **Tombol Aksi Utama (CTA):**
* Tombol aksi sekunder berlatar tonal muda di bagian bawah bertuliskan ikon daun dan teks **"Bagikan Sertifikat Bebas Mubazir"**.


* **Bottom Navigation Bar:**
* Docked di bagian bawah layar dengan 5 item: **Beranda**, **Stok**, **Limbah** (dalam kondisi aktif terbungkus pill hijau `#E8F0EA`), **Harga**, dan **Akun**.



---

## 2. Spesifikasi Backend & Logika Sistem (Backend Architecture)

Sistem backend memproses data halaman Limbah secara otomatis tanpa memerlukan input manual baru dari pengguna, melainkan mengintegrasikan data historis dari tabel input penjualan harian dan target rekomendasi AI.

### A. Alur Logika Pemrosesan Data di Backend

1. **Kalkulasi Selisih Harian:**

$$\text{Limbah Potensial} = \text{Target Produksi AI} - \text{Jumlah Terjual}$$


2. **Mitigasi Dynamic Pricing:**
Sistem memperhitungkan porsi sisa yang berhasil diselamatkan melalui diskon otomatis menjelang tutup toko, menghasilkan angka **Limbah Akhir (Real Waste)**.
3. **Akumulasi Finansial & Karbon:**
* *Rugi Dicegah (Rp)* = Porsi Terselamatkan $\times$ Harga Jual Standar Menu.
* *Emisi Tercegah ($CO_2e$)* = Konversi berat sisa makanan yang berhasil dihindari terhadap emisi gas rumah kaca.



### B. Struktur Tabel Terkait pada MariaDB (`padan_db`)

1. **Tabel `waste_analytics_summary` (Akumulasi Bulanan):**
* `id` (INT, Primary Key, Auto Increment)
* `user_id` (INT, Foreign Key ke tabel `users`)
* `month_year` (VARCHAR, contoh: "2024-10")
* `total_saved_portions` (INT)
* `total_avoided_loss_idr` (DECIMAL)
* `total_co2_reduced_kg` (FLOAT)
* `waste_weight_kg` (FLOAT)



### C. Desain Endpoint API (FastAPI)

1. **Endpoint Ambil Data Ringkasan Limbah (`GET /api/v1/waste/summary`)**
* **Logika Backend:**
* Mengambil rekapitulasi data dari tabel `daily_sales` dan membandingkannya dengan target `ai_predictions`.
* Menghitung akumulasi dampak finansial kumulatif, total porsi bulan ini, serta emisi tercegah.
* Mengembalikan data deret waktu (*time-series*) 4 bulan terakhir untuk merender grafik batang di frontend secara dinamis.




2. **Endpoint Unduh Laporan PDF (`GET /api/v1/waste/download-report`)**
* **Logika Backend:**
* Melakukan *query* data audit bulanan pengguna, merender dokumen laporan formal berformat PDF, dan mengembalikan *file stream* ke perangkat pengguna.
