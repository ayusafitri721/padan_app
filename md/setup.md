Saya sedang mengembangkan aplikasi Flutter bernama PADAN (Sistem Prediksi 
Permintaan dan Dynamic Pricing Berbasis AI untuk Mencegah Food Waste pada 
UMKM Kuliner), untuk keperluan Business Plan Competition dengan tema 
Digital Technology & Business Innovation.

KONTEKS PROJECT:
- Project Flutter sudah dibuat dengan nama "padan_app" dan sudah berhasil 
  dijalankan (flutter run sukses, masih tampilan default counter app)
- Tech stack: Flutter (frontend), FastAPI (backend, belum disetup), 
  MariaDB via Laragon (database, belum disetup)
- SEMUA development untuk saat ini HANYA di LOCAL, belum deploy ke cloud
- Development dilakukan BERTAHAP per fitur, bukan sekaligus

DESIGN SYSTEM:
- Primary color: sage green #3A5A40
- Splash background: darker sage green #2A4530
- Background: soft off-white/cream #F9F6F0
- Text color: dark charcoal #1E293B
- Style: clean, minimalist, rounded cards, modern typography

TUGAS SEKARANG - Setup Awal & Splash Screen:

1. Bersihkan project default Flutter (hapus kode counter app bawaan)

2. Buat struktur folder yang rapi di dalam lib/, yaitu:
   - lib/screens/       (semua halaman UI)
   - lib/widgets/       (komponen reusable)
   - lib/models/        (struktur data)
   - lib/services/      (koneksi API, nanti dipakai)
   - lib/utils/         (helper functions)
   - lib/constants/     (warna, teks, konstanta lain)

3. Buat file lib/constants/app_colors.dart berisi konstanta warna sesuai 
   design system di atas

4. Buat file lib/screens/splash_screen.dart dengan splash screen sederhana:
   - Background warna sage green gelap (#2A4530)
   - Icon/logo di tengah (untuk sementara pakai icon bawaan Flutter yang 
     merepresentasikan makanan/mangkuk, nanti akan diganti asset logo asli)
   - Teks "PADAN" di bawah logo, bold, warna cream
   - Tagline "Selaraskan Pangan, Cegah Sisa" di bawah nama, lebih kecil
   - Semua terpusat (center) secara vertikal dan horizontal

5. Update lib/main.dart supaya:
   - Menghapus kode default counter app
   - MaterialApp mengarah ke SplashScreen sebagai halaman pertama
   - Judul app "PADAN", tanpa debug banner

6. Pastikan project bisa dijalankan dengan `flutter run` tanpa error setelah 
   semua perubahan ini

ATURAN PENTING:
- Jangan tambahkan fitur lain di luar yang diminta (jangan langsung bikin 
  onboarding, login, dll — itu akan diminta terpisah di tahap berikutnya)
- Jelaskan secara singkat tiap file yang dibuat/diubah dan alasannya
- Setelah selesai, beri tahu langkah apa yang perlu saya lakukan untuk 
  menjalankan dan mengecek hasilnya
