package com.debdownplus.debdown_plus;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class DownloadService extends Service {

    private static final String TAG = "DebDownPlus-DL";
    private static final String CHANNEL_ID = "debdown_downloads";
    private static final int NOTIFICATION_ID = 1337;

    private ExecutorService executor = Executors.newSingleThreadExecutor();
    private NotificationManager notificationManager;
    private Handler mainHandler = new Handler(Looper.getMainLooper());

    // Active download state
    private Process currentProcess;
    private String currentUrl;
    private String currentDir;
    private String currentFormat;
    private String currentFileName;
    private boolean isCancelled = false;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) return START_STICKY;

        String action = intent.getAction();
        if ("START_DOWNLOAD".equals(action)) {
            currentUrl = intent.getStringExtra("url");
            currentDir = intent.getStringExtra("dir");
            currentFormat = intent.getStringExtra("format");
            currentFileName = intent.getStringExtra("name");
            isCancelled = false;

            startForeground(NOTIFICATION_ID, buildNotification("Memulai...", 0, false));
            executor.execute(this::runDownload);
        } else if ("CANCEL_DOWNLOAD".equals(action)) {
            cancelDownload();
        }

        return START_STICKY;
    }

    private void runDownload() {
        try {
            // Ensure yt-dlp binary exists
            File ytdlpBinary = ensureYtDlpBinary();
            if (ytdlpBinary == null) {
                updateNotification("Error: yt-dlp binary tidak ditemukan", 0, true);
                stopSelf();
                return;
            }

            // Prepare output directory
            File outputDir = new File(currentDir);
            if (!outputDir.exists() && !outputDir.mkdirs()) {
                updateNotification("Error: Gagal buat direktori", 0, true);
                stopSelf();
                return;
            }

            // Build yt-dlp command
            String outputTemplate = new File(outputDir, 
                (currentFileName != null && !currentFileName.isEmpty() ? currentFileName : "%(title)s.%(ext)s")).getAbsolutePath();
            
            String format = "mp3".equals(currentFormat) ? "bestaudio/best" : "bestvideo+bestaudio/best";
            String mergeOutputFormat = "mp3".equals(currentFormat) ? "mp3" : "mp4";

            String[] cmd = {
                ytdlpBinary.getAbsolutePath(),
                "--no-cache-dir",
                "--no-playlist",
                "-f", format,
                "--merge-output-format", mergeOutputFormat,
                "-o", outputTemplate,
                "--newline",
                "--progress-template", "download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
                currentUrl
            };

            updateNotification("Menyiapkan download...", 5, false);

            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.directory(outputDir);
            pb.redirectErrorStream(true);
            
            currentProcess = pb.start();

            // Read output for progress
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(currentProcess.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null && !isCancelled) {
                    parseProgress(line);
                }
            }

            int exitCode = currentProcess.waitFor();
            
            if (isCancelled) {
                updateNotification("Dibatalkan", 0, true);
            } else if (exitCode == 0) {
                updateNotification("Selesai! ✓", 100, true);
                // Notify Flutter via broadcast or event channel
                sendBroadcast(new Intent("com.debdownplus.DOWNLOAD_COMPLETE")
                    .putExtra("url", currentUrl)
                    .putExtra("dir", currentDir));
            } else {
                updateNotification("Error: Exit code " + exitCode, 0, true);
            }

        } catch (Exception e) {
            Log.e(TAG, "Download error", e);
            updateNotification("Error: " + e.getMessage(), 0, true);
        } finally {
            currentProcess = null;
            // Stop foreground after delay
            mainHandler.postDelayed(this::stopForegroundService, 3000);
        }
    }

    private void parseProgress(String line) {
        // yt-dlp progress format: download:XX.X%|XX KiB/s|HH:MM:SS
        if (line.startsWith("download:")) {
            String[] parts = line.substring(9).split("\\|");
            if (parts.length >= 1) {
                String percentStr = parts[0].replace("%", "").trim();
                try {
                    float percent = Float.parseFloat(percentStr);
                    String speed = parts.length > 1 ? parts[1].trim() : "";
                    String eta = parts.length > 2 ? parts[2].trim() : "";
                    updateNotification("Downloading... " + speed, (int) percent, false);
                } catch (NumberFormatException ignored) {}
            }
        } else if (line.contains("[download]") && line.contains("%")) {
            // Fallback parsing
            String[] tokens = line.split("\\s+");
            for (String token : tokens) {
                if (token.endsWith("%")) {
                    try {
                        float percent = Float.parseFloat(token.replace("%", ""));
                        updateNotification("Downloading...", (int) percent, false);
                        break;
                    } catch (NumberFormatException ignored) {}
                }
            }
        } else if (line.startsWith("[info]") || line.startsWith("[debug]")) {
            // Log info lines
            Log.d(TAG, line);
        }
    }

    private File ensureYtDlpBinary() {
        File binDir = new File(getFilesDir(), "bin");
        if (!binDir.exists()) binDir.mkdirs();
        
        File ytdlp = new File(binDir, "yt-dlp");
        if (ytdlp.exists() && ytdlp.canExecute()) {
            return ytdlp;
        }

        // Try to extract from assets or download
        try {
            // First try: copy from assets (bundled in APK)
            InputStream is = getAssets().open("yt-dlp");
            copyBinary(is, ytdlp);
            ytdlp.setExecutable(true);
            return ytdlp;
        } catch (IOException e) {
            Log.w(TAG, "yt-dlp not in assets, downloading...");
        }

        // Second try: download latest release
        return downloadYtDlpBinary(ytdlp);
    }

    private File downloadYtDlpBinary(File target) {
        String arch = System.getProperty("os.arch").toLowerCase();
        String assetName;
        if (arch.contains("aarch64") || arch.contains("arm64")) {
            assetName = "yt-dlp_linux_arm64";
        } else if (arch.contains("arm")) {
            assetName = "yt-dlp_linux_armv7l";
        } else if (arch.contains("x86_64") || arch.contains("amd64")) {
            assetName = "yt-dlp_linux_x86_64";
        } else {
            assetName = "yt-dlp_linux_arm64"; // default
        }

        String url = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/" + assetName;
        
        try {
            URL downloadUrl = new URL(url);
            HttpURLConnection conn = (HttpURLConnection) downloadUrl.openConnection();
            conn.setRequestMethod("GET");
            conn.setConnectTimeout(30000);
            conn.setReadTimeout(120000);
            
            try (InputStream is = conn.getInputStream();
                 FileOutputStream fos = new FileOutputStream(target)) {
                byte[] buffer = new byte[8192];
                int len;
                while ((len = is.read(buffer)) > 0) {
                    fos.write(buffer, 0, len);
                }
            }
            
            target.setExecutable(true);
            return target;
            
        } catch (IOException e) {
            Log.e(TAG, "Failed to download yt-dlp", e);
            return null;
        }
    }

    private void copyBinary(InputStream is, File target) throws IOException {
        try (FileOutputStream fos = new FileOutputStream(target)) {
            byte[] buffer = new byte[8192];
            int len;
            while ((len = is.read(buffer)) > 0) {
                fos.write(buffer, 0, len);
            }
        }
    }

    private void cancelDownload() {
        isCancelled = true;
        if (currentProcess != null) {
            currentProcess.destroyForcibly();
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "DebDown+ Downloads",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Progress download video/audio");
            channel.enableVibration(false);
            channel.setSound(null, null);
            notificationManager.createNotificationChannel(channel);
        }
    }

    private Notification buildNotification(String text, int progress, boolean finished) {
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("DebDown+")
            .setContentText(text)
            .setOngoing(!finished)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setAutoCancel(finished);

        if (progress > 0 && progress < 100) {
            builder.setProgress(100, progress, false);
        }

        if (finished) {
            builder.setProgress(0, 0, false);
            builder.setOngoing(false);
        }

        // Add cancel action
        if (!finished) {
            Intent cancelIntent = new Intent(this, DownloadService.class)
                .setAction("CANCEL_DOWNLOAD");
            PendingIntent cancelPending = PendingIntent.getService(
                this, 0, cancelIntent, PendingIntent.FLAG_IMMUTABLE);
            builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Batal", cancelPending);
        }

        return builder.build();
    }

    private void updateNotification(String text, int progress, boolean finished) {
        mainHandler.post(() -> {
            if (notificationManager != null) {
                notificationManager.notify(NOTIFICATION_ID, buildNotification(text, progress, finished));
            }
        });
    }

    private void stopForegroundService() {
        stopForeground(true);
        stopSelf();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        cancelDownload();
        executor.shutdownNow();
        super.onDestroy();
    }
}