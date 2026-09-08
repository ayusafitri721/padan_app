# Dokumentasi Komprehensif (Frontend & Backend): Alur Input Penjualan Harian Menuju Detail Prediksi AI - PADAN

---

## 1. Spesifikasi Frontend UI/UX (Antarmuka Pengguna)

Alur dimulai dari halaman **Input Penjualan Harian** (pada tab **Stok**) di mana pengguna memasukkan data harian dan menekan tombol simpan, yang kemudian mengarahkan alur navigasi mendalam ke halaman **Detail Prediksi AI** (berdasarkan referensi UI yang disertakan).

### A. Halaman Input Penjualan Harian (Menu Stok)

* **Header & Status Rutinitas:** Menampilkan status **Rutinita Tutup Warung** berlatar hijau matcha lembut dengan tanggal aktif (*Hari Ini, 24 Okt 2024*).
* **Toggle Toko Libur:** Fitur pilihan opsional untuk mencegah AI salah membaca angka nol sebagai penurunan tren.
* **Daftar Menu & Kartu Interaktif:** Setiap kartu menu menyajikan nama menu, target vs sisa porsi, tombol preset instan (misal *Habis (50)*), serta kontrol **Numeric Quantity Stepper** (`–` / `+`) yang dirancang dengan sudut membulat 12px dan tinggi 44px sesuai spesifikasi desain sistem.
* **Ringkasan AI & Tombol Aksi:** Kotak ringkasan efisiensi harian (misal *145 porsi terjual, 96.7% efisiensi*) diikuti tombol utama berwarna hijau sage (`#3A5A40`) berukuran tinggi 48–52px dengan radius penuh (`9999px`) bertuliskan **"Simpan Data Penjualan Hari Ini"**. Ketika tombol ini ditekan, sistem menavigasi pengguna ke layar analitik mendalam (*Detail Prediksi AI*).

### B. Halaman Detail Prediksi AI (Hasil Navigasi Lanjutan)

* **Top Bar:** Tombol kembali (*back arrow*), badge status model AI aktif (*"PADAN-AI Engine v2.4"*), dan ikon bagikan (*share*).
* **Header Menu & Target Waktu:** Menampilkan nama menu utama (misal: *Nasi Goreng Spesial*) beserta SKU (`SKU #NG-01`), kategori, persentase akurasi model (*Akurasi Model 94.8%*), dan jadwal target waktu (*Target 25 Okt 2024 (Malam)*).
* **Kartu Utama Target Rekomendasi Masak:** Kartu gelap berdinding hijau sage tua (`#3A5A40`) yang menyoroti angka rekomendasi porsi besar (misal: **55 Porsi**), lengkap dengan rentang aman adaptif (Batas Bawah 52, Titik Manis 55, Batas Atas 58) serta estimasi pengurangan emisi karbon ($CO_2e$).
* **Faktor Analisis Multidimensi (4 Parameter):** Kartu rincian faktor pendorong AI:
1. *Riwayat Tren Jumat* (+5 porsi)
2. *Cuaca BMKG Real-Time* (Cerah 28°C, +2 porsi)
3. *Event Eksternal Sekitar* (Konser musik di GBK, visual peta mikro-lokasi, +5 porsi)
4. *Koreksi Sisa Kemarin* (Mitigasi sisa semalam, -2 porsi)


* **Komponen Kebutuhan Bahan Baku:** Menampilkan rincian logistik bahan mentah per porsi (misal: *Beras Pulen 5.5 kg*, *Telur Ayam 55 butir*, *Daging Ayam 2.2 kg* dengan peringatan batas stok kurang).
* **Kalibrasi Manual & Tombol Kunci:** Kontrol *Stepper* penyesuaian manual (jika ada pesanan *catering* tambahan) dan tombol aksi utama di bagian bawah bertuliskan ikon gembok dan teks **"Kunci & Terapkan Angka Ini"**.

---

## 2. Spesifikasi Backend & Logika Sistem (Backend Architecture)

Sistem backend menggunakan RESTful API berbasis **FastAPI** yang terhubung langsung dengan basis data relasional **MariaDB** (memanfaatkan tabel riwayat migrasi yang sudah tersedia pada struktur `padan_db`).

### A. Struktur Skema Basis Data (MariaDB)

1. **Tabel `menus` (Manajemen Menu Usaha Kuliner):**
* `id` (INT, Primary Key, Auto Increment)
* `user_id` (INT, Foreign Key ke tabel `users`)
* `menu_name` (VARCHAR)
* `category` (VARCHAR)
* `sku_code` (VARCHAR, Unique)
* `standard_price` (DECIMAL)


2. **Tabel `daily_sales` & `daily_sales_items` (Pencatatan Penjualan):**
* Menyimpan rincian porsi terjual, target, serta status *is_holiday_toggle* harian untuk melatih model *Prophet/XGBoost*.


3. **Tabel `ai_predictions` (Riwayat & Faktor Analisis AI):**
* `id` (INT, Primary Key, Auto Increment)
* `menu_id` (INT, Foreign Key ke tabel `menus`)
* `prediction_date` (DATE)
* `recommended_portions` (INT)
* `accuracy_score` (FLOAT)
* `multidimensional_factors` (JSON, menyimpan log faktor cuaca BMKG, event eksternal, dan tren historis)



### B. Desain Endpoint API (FastAPI)

1. **Endpoint Simpan Penjualan & Alih ke Analitik (`POST /api/v1/sales/submit-and-analyze`)**
* **Payload Request (JSON):**
```json
{
  "date": "2024-10-24",
  "is_holiday_toggle": false,
  "items": [
    { "menu_id": 1, "sold_portions": 48 },
    { "menu_id": 2, "sold_portions": 32 }
  ]
}

```


* **Logika Backend:**
* Memproses data input harian kasir, memperbarui status stok fisik, dan memicu kalkulasi ulang model prediksi *Prophet/XGBoost* untuk hari berikutnya.
* Mengembalikan respons kode `200 OK` beserta `prediction_session_id` yang langsung digunakan frontend untuk merender halaman **Detail Prediksi AI**.




2. **Endpoint Ambil Detail Analisis Prediksi (`GET /api/v1/predictions/detail/{menu_id}`)**
* **Logika Backend:**
* Mengambil data parameter terkini dari API BMKG, database event eksternal lokal, serta koreksi sisa bahan kemarin.
* Menyusun variabel json multidimensi dan merespons dengan rincian angka rentang aman adaptif (Batas Bawah, Titik Manis, Batas Atas) serta daftar kebutuhan bahan baku logistik secara real-time.


---

name: Padan Agro-Culinary Mobile System

colors:

  surface: '#f9f9ff'

  surface-dim: '#cfdaf2'

  surface-bright: '#f9f9ff'

  surface-container-lowest: '#ffffff'

  surface-container-low: '#f0f3ff'

  surface-container: '#e7eeff'

  surface-container-high: '#dee8ff'

  surface-container-highest: '#d8e3fb'

  on-surface: '#111c2d'

  on-surface-variant: '#424842'

  inverse-surface: '#263143'

  inverse-on-surface: '#ecf1ff'

  outline: '#727971'

  outline-variant: '#c2c8bf'

  surface-tint: '#45664b'

  primary: '#23422a'

  on-primary: '#ffffff'

  primary-container: '#3a5a40'

  on-primary-container: '#acd0af'

  inverse-primary: '#abd0af'

  secondary: '#406840'

  on-secondary: '#ffffff'

  secondary-container: '#beecb9'

  on-secondary-container: '#446c44'

  tertiary: '#5e3000'

  on-tertiary: '#ffffff'

  tertiary-container: '#804300'

  on-tertiary-container: '#ffb87e'

  error: '#ba1a1a'

  on-error: '#ffffff'

  error-container: '#ffdad6'

  on-error-container: '#93000a'

  primary-fixed: '#c7ecca'

  primary-fixed-dim: '#abd0af'

  on-primary-fixed: '#02210c'

  on-primary-fixed-variant: '#2e4e35'

  secondary-fixed: '#c1eebc'

  secondary-fixed-dim: '#a5d2a2'

  on-secondary-fixed: '#002106'

  on-secondary-fixed-variant: '#284f2a'

  tertiary-fixed: '#ffdcc3'

  tertiary-fixed-dim: '#ffb77d'

  on-tertiary-fixed: '#2f1500'

  on-tertiary-fixed-variant: '#6e3900'

  background: '#f9f9ff'

  on-background: '#111c2d'

  surface-variant: '#d8e3fb'

typography:

  display-lg:

    fontFamily: Plus Jakarta Sans

    fontSize: 36px

    fontWeight: '700'

    lineHeight: 44px

    letterSpacing: -0.02em

  headline-lg:

    fontFamily: Plus Jakarta Sans

    fontSize: 28px

    fontWeight: '700'

    lineHeight: 36px

    letterSpacing: -0.01em

  headline-lg-mobile:

    fontFamily: Plus Jakarta Sans

    fontSize: 24px

    fontWeight: '700'

    lineHeight: 32px

    letterSpacing: -0.01em

  headline-md:

    fontFamily: Plus Jakarta Sans

    fontSize: 20px

    fontWeight: '600'

    lineHeight: 28px

  title-lg:

    fontFamily: Plus Jakarta Sans

    fontSize: 18px

    fontWeight: '600'

    lineHeight: 24px

  title-sm:

    fontFamily: Plus Jakarta Sans

    fontSize: 16px

    fontWeight: '600'

    lineHeight: 22px

  body-lg:

    fontFamily: Plus Jakarta Sans

    fontSize: 16px

    fontWeight: '400'

    lineHeight: 24px

  body-md:

    fontFamily: Plus Jakarta Sans

    fontSize: 14px

    fontWeight: '400'

    lineHeight: 20px

  body-sm:

    fontFamily: Plus Jakarta Sans

    fontSize: 13px

    fontWeight: '400'

    lineHeight: 18px

  label-md:

    fontFamily: Plus Jakarta Sans

    fontSize: 12px

    fontWeight: '600'

    lineHeight: 16px

    letterSpacing: 0.01em

  label-sm:

    fontFamily: Plus Jakarta Sans

    fontSize: 11px

    fontWeight: '500'

    lineHeight: 14px

    letterSpacing: 0.02em

  numeric-stat:

    fontFamily: Plus Jakarta Sans

    fontSize: 24px

    fontWeight: '700'

    lineHeight: 28px

rounded:

  sm: 0.25rem

  DEFAULT: 0.5rem

  md: 0.75rem

  lg: 1rem

  xl: 1.5rem

  full: 9999px

spacing:

  none: 0px

  2xs: 4px

  xs: 8px

  sm: 12px

  md: 16px

  lg: 20px

  xl: 24px

  2xl: 32px

  3xl: 40px

  screen-edge-mobile: 16px

  screen-edge-tablet: 24px

  card-padding: 16px

  bottom-nav-height: 76px

---



## Brand & Style

The design system powers an inventory control and food waste mitigation platform tailored for culinary SMEs, local warungs, and food artisans ("Selaraskan Pangan, Cegah Sisa"). The brand personality balances organic sustainability with operational rigor: grounded, empathetic, trustworthy, and technologically capable. 



The aesthetic marries **modern functional minimalism** with **warm organic tactility**. Instead of cold, clinical SaaS interfaces, it adopts natural botanic greens, soft off-white canvas surfaces, gentle pill geometry, and clear visual hierarchy that simplifies high-stress kitchen and pantry workflows during peak commercial hours. The visual language conveys calm competence, encouraging small business owners to monitor spoilage, balance supply lines, and implement dynamic markdown pricing without cognitive friction.



## Colors

The palette grounds the interface in agricultural tones while preserving digital contrast standards (WCAG AAA for text, AA for operational controls):



- **Primary (`#3A5A40`)**: Deep sage forest green. Serves as primary action buttons, key brand headers, and high-emphasis active navigation states.

- **Secondary (`#588157`)**: Verdant leaf green. Used for positive metric trends, secondary toggles, progress bars, and operational confirmations.

- **Tertiary / Accent (`#D97706`)**: Warm amber. Reserved specifically for food waste alerts, nearing expiration thresholds, urgent discounts, and warning banners.

- **Neutral Core (`#1E293B`)**: Deep slate charcoal. Replaces harsh true black for headings and high-fidelity legible text.

- **Muted Text (`#64748B`)**: Balanced slate gray for timestamps, secondary subtitles, metadata, and inactive icons.

- **Background Canvas (`#F9F6F0`)**: Warm cream off-white that reduces glare in high-brightness mobile environments while giving an artisanal warmth.

- **Surface (`#FFFFFF`)**: Pure crisp white for elevated metric cards, modular inputs, and floating bottom sheets.

- **Tonal Badge Base (`#E8F0EA`)**: Low-saturation matcha tint utilized for pill tags, active icon backgrounds, and AI prediction cards.



## Typography

Plus Jakarta Sans serves as the single typographic voice across headlines, body copy, and UI tags. Its contemporary geometric proportions and humanist curves impart warmth and optimal legibility on small-format handheld screens. 



- **Weight Discipline**: Restrict weight usage strictly to `700` (Bold for page targets and key efficiency statistics), `600` (SemiBold for card headings and section titles), `500` (Medium for navigation labels and badge text), and `400` (Regular for descriptions and list items).

- **Numeric Optimization**: All tabular quantities, stock counts, currency (`Rp`), and efficiency percentages employ tabular lining numbers where supported to guarantee alignment across data grids.



## Layout & Spacing

The layout model employs a mobile-first fluid grid structured on an 8pt base grid with a 4pt sub-rhythm for tight inline compositions.



- **Mobile Viewports (< 600px)**: Content runs along a single column with fixed screen-edge margins of `16px`. Internal card padding is locked to `16px`, with vertical stack rhythms separated by `12px` or `16px`.

- **Tablet / Expanded Screen (600px - 1024px)**: Transition into a 6-column fluid grid with `24px` margins and `16px` gutters. Analytical dashboards split into 2-column or 3-column card modules.

- **Touch-Target Integrity**: All interactive control elements (quantity steppers, bottom nav tabs, delete buttons) maintain a minimum hit area of 44脳44px, irrespective of visible icon bounds.



## Elevation & Depth

Depth is constructed through subtle chromatic containment rather than deep drop shadows, avoiding visual dirt on off-white backgrounds:



- **Surface Level 0 (Base Canvas)**: `#F9F6F0` flat background canvas.

- **Surface Level 1 (Card & Module Deck)**: `#FFFFFF` pure white, paired with an ultra-fine border (`1px solid #E2DDD5`) and soft ambient occlusion: `0px 2px 8px rgba(30, 41, 59, 0.04)`.

- **Surface Level 2 (Floating Toggles & Alerts)**: Crisp card overlay, supported by `0px 8px 20px rgba(58, 90, 64, 0.08)`.

- **Surface Level 3 (Fixed Bottom Navigation Bar)**: Detached floating pill or bottom-docked panel finished with `0px -4px 24px rgba(30, 41, 59, 0.06)`, producing clear spatial isolation from scrolling feed items underneath.



## Shapes

The shape language uses friendly, ergonomic curves:

- **Base Components & Form Fields**: `12px` to `16px` corner radius.

- **Card Containers & Modal Sheets**: Standardized at `20px` to `24px` radius, echoing modern handheld hardware bezels.

- **Pill Badges & Navigation Buttons**: Full radius `9999px` (circular caps) for quick-status chips, category pills, and full-width primary CTA buttons.



## Components



### 1. Primary & Secondary Buttons

- **Primary CTA**: Background `#3A5A40`, text `#FFFFFF`, radius `9999px`, height `48px` to `52px`, font `Plus Jakarta Sans 600`. Pressed state: `#2F4833`.

- **Secondary / Action Tonal**: Background `#E8F0EA`, text `#3A5A40`, borderless, radius `9999px`.

- **Destructive / Ghost**: Border `1px solid transparent`, icon/text `#DC2626` or `#64748B`.



### 2. Cards & Stat Widgets

- Pure white container with `16px` internal padding, `20px` corner radius, and `1px solid #E2DDD5`.

- Statistic counters pair a muted category label (`12px`, `#64748B`) with a bold numeral (`24px`, `#1E293B`), often tagged with an inline trend pill (`#E8F0EA` containing a `#3A5A40` percentage).



### 3. Pill Badges & Chips

- Padding: `4px 12px`. Corner radius: `9999px`.

- **Standard Soft Pill**: `#E8F0EA` background with `#3A5A40` text.

- **Warning / Food Waste Risk**: `#FEF3C7` background with `#D97706` text.

- **Active Filter**: Solid `#3A5A40` fill with white text.



### 4. Input Fields & Steppers

- Height `44px`, background `#FFFFFF`, border `1px solid #E2DDD5`, radius `12px`.

- Focus ring: `2px solid #3A5A40` without heavy offset glow.

- **Numeric Quantity Stepper**: Compact enclosed container with minus/plus icons enclosed by subtle vertical dividers, allowing rapid single-tap kitchen stock increments.



### 5. Five-Item Bottom Navigation Bar

- Docked or floating bottom bar hosting five core destinations: **Beranda**, **Stok**, **Limbah**, **Harga**, and **Akun**.

- Surface: `#FFFFFF` with top edge hairline divider `#E2DDD5`.

- Active Item: Wrapped in a soft green pill background (`#E8F0EA`), sporting icon and label in `#3A5A40`.

- Inactive Items: Icon and label in `#64748B`.



### 6. Food Waste & Dynamic Pricing Modules

- **Waste Alert Banner**: Warning card highlighted by a `4px` left accent strip in `#D97706` on white, warning the user of items approaching expiry.

- **Automated Pricing Slider**: Track finished in `#E8F0EA`, filled track in `#588157`, thumb in crisp `#FFFFFF` with a subtle elevation shadow and `#3A5A40` border.
