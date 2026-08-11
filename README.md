<h1 align="center">⚡ DebDown+</h1>
<p align="center"><b>Video / Audio Downloader • yt-dlp Native • Glitch Hacker Theme</b></p>

<p align="center">
  <a href="https://github.com/debzroot/debdownplus/releases/latest"><img alt="Latest Release" src="https://img.shields.io/github/v/release/debzroot/debdownplus?style=for-the-badge&color=39FF14&labelColor=050505"></a>
  <a href="https://github.com/debzroot/debdownplus/actions"><img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/debzroot/debdownplus/build.yml?style=for-the-badge&color=39FF14&labelColor=050505&logo=github"></a>
  <a href="https://github.com/debzroot/debdownplus/releases/latest"><img alt="Downloads" src="https://img.shields.io/github/downloads/debzroot/debdownplus/total?style=for-the-badge&color=39FF14&labelColor=050505"></a>
  <a href="https://github.com/debzroot/debdownplus/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/debzroot/debdownplus?style=for-the-badge&color=39FF14&labelColor=050505"></a>
</p>

---

## 🎯 Apa Itu DebDown+?

**Downloader video & audio multi-platform** yang jalan di Android pakai **yt-dlp native** (bukan wrapper Dart yang ketinggalan jaman). Engine-nya **binary asli yt-dlp + ffmpeg** yang di-compile untuk ARM — jadi support **1000+ situs** sebenernya, bukan cuma YouTube.

| Fitur | Status |
|-------|--------|
| 🎬 **MP4 (Video + Audio muxed)** | ✅ |
| 🎵 **MP3 (Audio only, best quality)** | ✅ |
| 🔗 **Share intent dari YouTube/TikTok/IG/FB/X** | ✅ |
| 🔄 **Auto-update yt-dlp tiap buka app** | ✅ |
| 📁 **Simpan ke `/Download/DebDown+`** | ✅ |
| 🖥 **Terminal console live + syntax highlight** | ✅ |
| 📋 **System logs + Share logs.txt** | ✅ |
| 🎨 **Glitch hacker theme (dark #050505, neon #39FF14)** | ✅ |

---

## 📥 Download Latest

> **Pilih yang cocok buat HP kamu:**

| Arsitektur | File | Ukuran | Cocok Buat |
|------------|------|--------|------------|
| **arm64-v8a** | [`DebDownPlus-v1.3.3-arm64-v8a.apk`](https://github.com/debzroot/debdownplus/releases/download/v1.3.3/DebDownPlus-v1.3.3-arm64-v8a.apk) | 61.8 MB | **HP modern 2017+ (ampir semua)** |
| **armeabi-v7a** | [`DebDownPlus-v1.3.3-armeabi-v7a.apk`](https://github.com/debzroot/debdownplus/releases/download/v1.3.3/DebDownPlus-v1.3.3-armeabi-v7a.apk) | **54.7 MB** | HP lama 32-bit (pre-2017) |
| **x86_64** | [`DebDownPlus-v1.3.3-x86_64.apk`](https://github.com/debzroot/debdownplus/releases/download/v1.3.3/DebDownPlus-v1.3.3-x86_64.apk) | 65.0 MB | Emulator saja |
| **Universal** | [`DebDownPlus.apk`](https://github.com/debzroot/debdownplus/releases/download/v1.3.3/DebDownPlus.apk) | 61.8 MB | Copy arm64 (default) |

👉 **Bingung? Download `DebDownPlus.apk` aja — itu versi arm64 yang paling umum dipakai.**

---

## 🛠 Install & Setup Pertama Kali

```bash
# 1. Install APK (lewat file manager / browser)
# 2. Buka app → izinkan permission:
#    ☑ Files and media (Storage)
#    ☑ All files access (Manage External Storage) ← WAJIB biar bisa tulis ke /Download/
# 3. Paste link → pilih MP4/MP3 → START DOWNLOAD
# 4. File ada di: /Download/DebDown/
```

> ⚠ **Realme / ColorOS / MIUI / HyperOS user:**  
> Settings → Apps → DebDown+ → **All files access** → **Allow**  
> Kalau ga di-allow, download **bakal gagal** (Permission denied).

---

## 🎮 Cara Pakai

### Metode 1: Paste Link Manual
```
1. Buka DebDown+
2. Paste link (YT / TikTok / IG / FB / X / SoundCloud / dll)
3. Pilih format: ⚡ MP4 (Video)  atau  ⚡ MP3 (Audio)
4. Tekan START DOWNLOAD
5. Lihat progress di TERMINAL (live)
6. Selesai → file ada di /Download/DebDown/
```

### Metode 2: Share Dari App Lain (Paling Cepat)
```
1. Buka YouTube / TikTok / Instagram / Facebook / X
2. Tekan Share → pilih "DebDown+"
3. App kebuka otomatis, link sudah terisi
4. Pilih format → START DOWNLOAD
```

---

## 🖥 Terminal Console — Apa Saja Yang Muncul?

```
[2026-08-11 13:37:42] SYSTEM READY [v1.3.3]
[2026-08-11 13:37:45] Engine initialized: vnull
[2026-08-11 13:37:49] Engine update: DONE (vyt-dlp 2026.07.04)
[2026-08-11 13:38:12] Download request: https://youtu.be/xxx (format: mp4)
[2026-08-11 13:38:12] Target dir: /storage/emulated/0/Download/DebDown+
[2026-08-11 13:38:13] ⚡DebDown+ downloading...
[2026-08-11 13:38:45] [SUCCESS] 100% - File saved: /Download/DebDown+/video.mp4
```

**Warna log:**
- 🟢 **Hijau** = Normal / Success
- 🔴 **Merah** = Error / Network Error / Failed
- 🟡 **Kuning** = Info / Warning / Progress %
- 🔵 **Cyan** = URL / Engine brand

---

## 📱 Tab DEV — Buat Apa?

- **🚀 DEVELOPER** — Info dev + glitch text
- **✨ Debz ✨** — Profil pembuat
- **☕ TRAKTIR KOPI 😁** — QR DANA (tap buat zoom)
- **// SYSTEM LOGS** — Riwayat lengkap error/debug
- **SHARE LOGS.TXT** — Kirim log ke dev buat analisa error

---

## 🏗 Tech Stack

| Layer | Teknologi |
|-------|-----------|
| **UI** | Flutter 3.19 + Custom Painter (GlitchBanner, Scanlines, Grid) |
| **Engine** | `youtubedl-android` v0.18.1 (yt-dlp + ffmpeg binary native ARM) |
| **IPC** | MethodChannel `debdown/ytdl` (Flutter ↔ Kotlin) |
| **Share Intent** | `receive_sharing_intent` v1.8.1 |
| **Permission** | `permission_handler` v11.3 (Storage + MANAGE_EXTERNAL_STORAGE) |
| **Storage** | `path_provider` + `Environment.getExternalStoragePublicDirectory` |
| **CI/CD** | GitHub Actions → `flutter build apk --split-per-abi` → `r0adkll/sign-android-release` → Auto GitHub Release |
| **Signing** | RSA-2048 self-signed keystore (valid 10.000 hari) |

---

## 📂 Struktur Project

```
debdownplus/
├── .github/workflows/build.yml    # CI/CD pipeline
├── android/
│   └── app/src/main/
│       ├── kotlin/com/debdownplus/debdown_plus/MainActivity.kt  # MethodChannel engine
│       ├── AndroidManifest.xml    # Permissions + intent filter + FileProvider
│       └── res/
│           ├── xml/file_provider_paths.xml
│           ├── mipmap-anydpi-v26/ # Adaptive icons + monochrome (Android 13+)
│           └── values/colors.xml
├── assets/
│   ├── profile.png
│   └── qr_dana.png
├── lib/
│   └── main.dart                  # 2300+ lines: UI + logic + terminal + glitch widgets
├── pubspec.yaml
└── README.md
```

---

## 🔧 Build Lokal (Kalau Mau)

```bash
# Prereq: Flutter 3.19+, Android SDK 34, Java 17
git clone https://github.com/debzroot/debdownplus.git
cd debdownplus
flutter pub get
flutter build apk --release --split-per-abi
# Output: build/app/outputs/flutter-apk/app-*-release.apk
```

> **Note:** CI pakai `flutter create .` tiap build biar scaffolding Android selalu fresh — jadi file `android/` di repo **harus** match package `com.debdownplus.debdown_plus`.

---

## 🐛 Known Issues / FAQ

| Masalah | Solusi |
|---------|--------|
| **Permission denied `/Download/DebDown+`** | Aktifkan **All files access** di Settings → Apps → DebDown+ |
| **Download TikTok/IG gagal** | Pastikan link **publik** (bukan private/reels butuh login). Engine yt-dlp butuh akses publik. |
| **Play Protect warning "Play Protect doesn't recognize this app"** | Normal untuk APK sideload. Tekan **"Install anyway"** / **"Lanjutkan install"**. Sudah di-sign proper (RSA-2048). |
| **File ga ketemu di gallery** | File di `/Download/DebDown+` — buka lewat **Files / My Files / File Manager**, bukan Gallery. |
| **Engine update lama / stuck** | Butuh internet. yt-dlp di-download dari GitHub (~15 MB). Tunggu sampe log nampilin `DONE`. |

---

## 🤝 Contributing

1. Fork repo
2. Branch: `git checkout -b fitur-keren`
3. Commit: `git commit -m "Add fitur keren"`
4. Push: `git push origin fitur-keren`
5. Open PR → review → merge

**Style guide:** Hacker theme, clean code, comment bahasa Indo/Inggris campur, no bloat.

---

## 📄 License

**MIT License** — bebas pakai, modif, distribusi, komersial.  
Lihat [LICENSE](LICENSE) buat detailnya.

> **Credit engine:** [yt-dlp](https://github.com/yt-dlp/yt-dlp) + [FFmpeg](https://ffmpeg.org/) + [youtubedl-android](https://github.com/junkfood02/youtubedl-android) — legend yang bikin downloader ini possible.

---

## 🙏 Credits & Thanks

- **@debzroot** — Creator, UI/UX, Flutter/Kotlin logic, CI/CD, icon design
- **yt-dlp team** — Engine paling powerful di universe
- **junkfood02** — `youtubedl-android` wrapper yang gampang di-embed
- **Flutter team** — Framework yang bikin cross-platform jadi enak
- **Kopi** — Fuel utama development ini ☕

---

<p align="center">
  <b>Made with ⚡ by Debz • Powered by yt-dlp • Glitch mode: ON</b><br>
  <sub>Star ⭐ repo ini kalau bermanfaat — motivation buat update terus!</sub>
</p>

<p align="center">
  <a href="https://github.com/debzroot/debdownplus/releases/latest"><img alt="Download Latest" src="https://img.shields.io/badge/⬇_DOWNLOAD_LATEST-v1.3.3-39FF14?style=for-the-badge&logo=github&labelColor=050505"></a>
</p>
