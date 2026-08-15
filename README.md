# DebDown+ - Video/Audio Downloader

Aplikasi downloader video & audio multi-platform untuk Android, powered by **yt-dlp + ffmpeg** (native ARM binary).

## ✨ Fitur

- 🎬 **MP4** (Video + Audio muxed)
- 🎵 **MP3** (Audio only, best quality)
- 🔗 **Share intent** dari YouTube/TikTok/IG/FB/X/SoundCloud/dll
- 🔄 **Auto-update yt-dlp** tiap buka app
- 📁 Simpan ke `/Download/DebDown+` (MediaStore API - compatible Android 10+)
- 📱 Support 1000+ situs via yt-dlp
- ⚡ Native ARM binary (arm64-v8a, armeabi-v7a, x86_64)

## 🛠 Build

### Prasyarat
- Flutter SDK >= 3.16
- Android SDK (API 34)
- NDK 26.x
- Java 17/21

### Build Commands
```bash
# Clone & setup
git clone https://github.com/debzroot/DebDown-Video-Audio-Downloader.git
cd DebDown-Video-Audio-Downloader

# Get dependencies
flutter pub get

# Build release APK (split per ABI)
flutter build apk --release --split-per-abi

# Atau build universal
flutter build apk --release
```

### Output
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk      # Modern devices (2017+)
├── app-armeabi-v7a-release.apk    # Legacy 32-bit
├── app-x86_64-release.apk         # Emulator only
└── app-release.apk                # Universal (all ABIs)
```

## 📱 Permission Handling (Android 10+)

Aplikasi ini menggunakan pendekatan modern untuk storage permission:

| Android Version | Permission Strategy |
|----------------|---------------------|
| **Android 11+ (API 30+)** | `MANAGE_EXTERNAL_STORAGE` (All Files Access) via Settings |
| **Android 10 (API 29)** | `READ_EXTERNAL_STORAGE` + `requestLegacyExternalStorage=true` |
| **Android 9- (API 28-)** | `WRITE_EXTERNAL_STORAGE` |

### Alur Permission:
1. App cek `Environment.isExternalStorageManager()` (API 30+)
2. Kalau belum granted → buka Settings `ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION`
3. User enable "Allow all files access" → kembali ke app
4. Download dimulai via `DownloadService` (foreground service)

### Penyimpanan File:
- **Primary**: `MediaStore.Downloads` → `/Download/DebDown+` (visible di Files app, gallery, dll)
- **Fallback**: `getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)/DebDown+` (app-specific, auto-clean saat uninstall)
- **Last resort**: Internal storage (`filesDir/DebDown+`)

## 🔧 Arsitektur

```
lib/
├── main.dart                    # Flutter UI
└── ...

android/app/src/main/
├── kotlin/
│   └── com/debdownplus/debdown_plus/
│       ├── MainActivity.kt      # FlutterActivity + MethodChannel bridge
│       └── DownloadService.kt   # Foreground service + yt-dlp execution
├── res/xml/
│   └── file_provider_paths.xml  # FileProvider config
└── AndroidManifest.xml          # Permissions + components
```

### Komunikasi Flutter ↔ Native:
- **MethodChannel** (`com.debdownplus/download`) untuk command: `download`, `defaultDir`, `init`, `update`, `cancel`, `shareFile`
- **Foreground Service** (`DownloadService`) untuk eksekusi yt-dlp di background dengan notifikasi progress
- **Broadcast** (`com.debdownplus.DOWNLOAD_COMPLETE`) untuk notifikasi selesai ke Flutter

## 📦 yt-dlp Binary

Binary yt-dlp di-bundle di `assets/yt-dlp` (per ABI) dan di-copy ke `filesDir/bin/` saat first run. Auto-update via GitHub Releases API.

## 🐛 Troubleshooting

### "Permission denied" di Oppo/ColorOS
- Pastikan "Allow all files access" **enabled** di Settings → Apps → DebDown+ → Permissions
- ColorOS butuh enable manual: Settings → Permission Manager → Files and Media → Allow all files

### Download gagal / stuck
- Cek notifikasi progress (foreground service)
- Pastikan koneksi internet stabil
- Coba update yt-dlp via menu → Update

### File tidak muncul di Gallery/Files
- File disimpan via MediaStore → harus visible
- Kalau tidak, cek `/Android/data/com.debdownplus.debdown_plus/files/Download/DebDown+`
- Atau gunakan fitur "Share" dari app untuk kirim ke app lain

## 📄 License

MIT License - Powered by yt-dlp & ffmpeg

## 🙏 Credits

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - The actual downloader
- [FFmpeg](https://ffmpeg.org/) - Media processing
- [Flutter](https://flutter.dev/) - UI framework