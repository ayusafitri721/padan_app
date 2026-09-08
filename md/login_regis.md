Dokumentasi Teknis Frontend & Backend: Halaman Login & Registrasi - PADAN

Aplikasi Manajemen Stok Cerdas & Pencegah Food Waste untuk UMKM Kuliner

Tagline: "Selaraskan Pangan, Cegah Sisa"
1. Spesifikasi Antarmuka & Pengalaman Pengguna (Frontend UI/UX)

Halaman Login dan Registrasi dirancang dengan prinsip desain minimalist modern, menggunakan full-width background berukuran penuh (edge-to-edge), serta mengusung palet warna identitas utama aplikasi.
A. Palet Warna & Elemen Visual

    Warna Latar (#F9F6F0): Krem lembut (soft cream / off-white) yang memberikan kesan bersih, nyaman di mata, dan ramah lingkungan.

    Warna Aksi Utama (#3A5A40): Hijau sage (sage green) untuk tombol utama dan elemen interaktif penting.

    Warna Teks (#1E293B): Dark charcoal untuk memastikan kontras dan keterbacaan teks yang tinggi.

    Elemen Dekoratif: Garis tipis line art organik (sayur dan daun pudar) di sudut-sudut layar (corner art) untuk mempermanis estetika tanpa mengganggu fokus pengguna.

B. Desain Komponen Halaman Registrasi (Daftar Akun UMKM)

    Header: Logo minimalis PADAN di bagian atas tengah, diikuti judul "Daftar Akun UMKM" dan sub-teks deskriptif.

    Form Input Interaktif:

        Nama Warung / Usaha: Kolom teks untuk identitas kuliner (contoh: Warung Nasi Bu Ani).

        Nomor HP / Email: Kolom kontak utama yang wajib diisi dan bersifat unik.

        Jenis Usaha (Dropdown): Pilihan kategori (Warung Makan, Katering, Restoran Non-Chain) untuk menyesuaikan parameter awal model AI.

        Kata Sandi: Kolom sandi aman yang dilengkapi tombol interaktif show/hide password (ikon mata).

    Tombol Aksi Utama (CTA): Tombol berbentuk pil penuh (rounded button) warna hijau sage bertuliskan "Daftar".

    Footer Navigation: Teks tautan bawah: "Sudah punya akun? Masuk di sini".

C. Desain Komponen Halaman Login (Masuk Akun)

    Header: Logo PADAN dan sapaan ramah "Selamat Datang Kembali!".

    Form Input Interaktif:

        Nomor HP / Email dan Kata Sandi (dengan fitur tersembunyi).

    Fitur Tambahan: Tautan teks "Lupa Kata Sandi?" di sudut kanan bawah kolom sandi.

    Tombol Aksi Utama (CTA): Tombol hijau sage penuh bertuliskan "Masuk".

    Footer Navigation: Teks tautan bawah: "Belum punya akun? Daftar sekarang".

2. Spesifikasi Sistem & Logika Pemrograman (Backend Architecture)

Sistem backend dikembangkan menggunakan kerangka kerja RESTful API berbasis FastAPI (Python) dan terhubung dengan basis data relasional MariaDB.
A. Skema Basis Data (MariaDB - Tabel users)

Penyimpanan data autentikasi dan profil UMKM pada tabel users memiliki struktur kolom berikut:

    id (INT, Primary Key, Auto Increment): Identifikasi unik pengguna.

    warung_name (VARCHAR): Nama usaha kuliner milik pengguna.

    phone_or_email (VARCHAR, Unique): Kontak unik untuk identitas login.

    business_type (VARCHAR): Kategori usaha (seperti Warung Makan, Katering, dll).

    password_hash (VARCHAR): Hasil enkripsi sandi menggunakan algoritma hashing yang aman.

    created_at (TIMESTAMP): Catatan waktu pembuatan akun.

B. Desain Endpoint API (FastAPI)

    Endpoint Registrasi Pengguna (POST /api/v1/auth/register)

        Fungsionalitas: Menerima payload data dari frontend (nama warung, kontak, jenis usaha, dan kata sandi).

        Logika Backend:

            Memeriksa ketersediaan phone_or_email di dalam basis data untuk menghindari duplikasi akun.

            Melakukan proses enkripsi terhadap kata sandi mentah menjadi password_hash.

            Menyimpan data ke dalam tabel users pada MariaDB.

            Mengembalikan respons sukses beserta Token Akses JWT (JSON Web Token) untuk sesi masuk otomatis.

    Endpoint Otentikasi Masuk (POST /api/v1/auth/login)

        Fungsionalitas: Memproses kredensial saat pengguna menekan tombol "Masuk".

        Logika Backend:

            Menerima parameter kredensial (phone_or_email dan password).

            Mencari kecocokan data pengguna di basis data berdasarkan kontak yang dimasukkan.

            Memverifikasi kecocokan kata sandi menggunakan fungsi dekripsi/pencocokan hash.

            Jika valid, menerbitkan token akses baru; jika tidak valid, mengembalikan kode error HTTP 401 (Unauthorized).
