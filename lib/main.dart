import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DebDownApp());
}

class DebDownApp extends StatelessWidget {
  const DebDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DebDown+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF39FF14),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  String _status = 'Ready';
  String _progress = '';
  double _progressValue = 0.0;
  bool _isDownloading = false;
  String _selectedFormat = 'mp4';
  String _downloadDir = '';
  
  static const MethodChannel _channel = MethodChannel('com.debdownplus/download');
  
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final dir = await _channel.invokeMethod<String>('defaultDir');
      setState(() => _downloadDir = dir ?? '');
      await _channel.invokeMethod('init');
      _checkPermissions();
    } catch (e) {
      _updateStatus('Init error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    if (await Permission.storage.isGranted || await Permission.manageExternalStorage.isGranted) {
      return;
    }
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      } else if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
  }

  void _updateStatus(String status, {String progress = '', double progressValue = 0.0}) {
    if (mounted) {
      setState(() {
        _status = status;
        _progress = progress;
        _progressValue = progressValue;
      });
    }
  }

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnack('Masukkan URL dulu!');
      return;
    }

    if (!await _checkPermissions()) {
      _showSnack('Izin storage diperlukan!');
      return;
    }

    setState(() {
      _isDownloading = true;
      _progressValue = 0.0;
      _progress = 'Memulai...';
    });

    try {
      final result = await _channel.invokeMethod('download', {
        'url': url,
        'dir': _downloadDir,
        'name': '', // auto-generate
        'format': _selectedFormat,
      });

      if (result == 'permission_granted') {
        // Download started in background - monitor via native
        _monitorDownload();
      } else {
        _updateStatus('Gagal: $result');
        setState(() => _isDownloading = false);
      }
    } on PlatformException catch (e) {
      _updateStatus('Error: ${e.message}');
      setState(() => _isDownloading = false);
    }
  }

  void _monitorDownload() {
    // In real app, use EventChannel for progress updates from native
    // For now, simulate
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isDownloading) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue = (_progressValue + 0.1).clamp(0.0, 1.0);
        _progress = 'Downloading... ${(_progressValue * 100).toInt()}%';
        if (_progressValue >= 1.0) {
          _isDownloading = false;
          _updateStatus('Selesai!', progress: 'File tersimpan di $_downloadDir');
          _showSnack('Download selesai!');
          timer.cancel();
        }
      });
    });
  }

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;
      return false;
    }
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFolder() async {
    // Use SAF to let user pick folder
    try {
      // Implementation would use file_picker or native SAF
    } catch (e) {
      _showSnack('Gagal pilih folder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DebDown+', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.update),
            onPressed: () => _channel.invokeMethod('update'),
            tooltip: 'Update yt-dlp',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickFolder,
            tooltip: 'Pilih folder download',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL Input
            Card(
              color: const Color(0xFF111111),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Video/Audio URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Paste link YouTube, TikTok, Instagram, Facebook, X, SoundCloud...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: const Color(0xFF0A0A0A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste, color: Color(0xFF39FF14)),
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              _urlController.text = data!.text!;
                            }
                          },
                        ),
                      ),
                      maxLines: 2,
                      onSubmitted: (_) => _startDownload(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Format Selection
            Card(
              color: const Color(0xFF111111),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Format', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormatOption(
                            label: 'MP4 Video',
                            value: 'mp4',
                            selected: _selectedFormat == 'mp4',
                            onTap: () => setState(() => _selectedFormat = 'mp4'),
                            icon: Icons.videocam,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormatOption(
                            label: 'MP3 Audio',
                            value: 'mp3',
                            selected: _selectedFormat == 'mp3',
                            onTap: () => setState(() => _selectedFormat = 'mp3'),
                            icon: Icons.music_note,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Download Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                icon: _isDownloading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.download_rounded, size: 28),
                label: Text(
                  _isDownloading ? 'Downloading...' : 'START DOWNLOAD',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: _isDownloading ? null : _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF39FF14),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Progress Area
            if (_isDownloading || _progress.isNotEmpty) ...[
              Card(
                color: const Color(0xFF111111),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_status, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('${(_progressValue * 100).toInt()}%', style: const TextStyle(fontSize: 14, color: Color(0xFF39FF14))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_progress.isNotEmpty)
                        Text(_progress, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progressValue,
                        backgroundColor: const Color(0xFF0A0A0A),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF39FF14)),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text('Info', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[400])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'File tersimpan di: $_downloadDir',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Support: YouTube, TikTok, Instagram, Facebook, X/Twitter, SoundCloud, dan 1000+ situs lain',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Engine: yt-dlp + ffmpeg (native ARM)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _FormatOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  const _FormatOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF39FF14) : const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.black : Colors.grey[500], size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.black : Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}