import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// ===== THEME (port of /var/www/html/css/base.css) =====
const kGreen = Color(0xFF39FF14);
const kGreenDim = Color(0x8039FF14);
const kPurple = Color(0xFFAF82FF);
const kRed = Color(0xFFFF5F56);
const kYellow = Color(0xFFFFBD2E);
const kCyan = Color(0xFF00FFFF);
const kBg = Color(0xFF050505);
const kGrid = Color(0x4D145014); // rgba(20,80,20,0.3)
const kGlassBorder = Color(0x8039FF14);
const kMono = 'monospace';

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        fontFamily: kMono,
        colorScheme: const ColorScheme.dark(
          primary: kGreen,
          secondary: kPurple,
          surface: Color(0xFF0F140F),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ===== HOME =====
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _ytdl = MethodChannel('debdown/ytdl');
  static const _ytdlEvents = EventChannel('debdown/ytdl/progress');

  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();
  String _selectedFormat = 'mp4';

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'SYSTEM READY [v1.2.0]';
  String _engineStatus = 'ENGINE INIT...';
  final List<String> _logs = [];
  late final AnimationController _cursorCtrl;

  StreamSubscription<dynamic>? _shareSub;
  StreamSubscription<dynamic>? _ytdlSub;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _log('App started v1.2.0');
    _requestPermissions();
    _initEngine();
    _initShareIntent();
    _ytdlSub = _ytdlEvents.receiveBroadcastStream().listen(_onEngineEvent);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _ytdlSub?.cancel();
    _cursorCtrl.dispose();
    _urlController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  // ===== LOGGING =====
  void _log(String message) {
    final ts = DateTime.now().toString().substring(0, 19);
    _logs.add('[$ts] $message');
    if (_logs.length > 200) _logs.removeAt(0);
    debugPrint('[DebDown+] $message');
  }

  // ===== ENGINE (yt-dlp native) =====
  Future<void> _initEngine() async {
    try {
      final v = await _ytdl.invokeMethod<String>('init');
      setState(() => _engineStatus = 'ENGINE v$v');
      _log('Engine initialized: v$v');
      // Auto-update engine from GitHub (fire & forget)
      _ytdl.invokeMethod('update').then((res) {
        _log('Auto-update result: $res');
      }).catchError((e) {
        _log('Auto-update skipped: ${e.message}');
      });
    } catch (e) {
      setState(() => _engineStatus = 'ENGINE ERROR');
      _log('Engine init error: $e');
    }
  }

  void _onEngineEvent(dynamic event) {
    if (!mounted) return;
    final m = (event as Map).cast<String, dynamic>();
    final type = m['type'];
    if (type == 'update') {
      final status = m['status'] ?? '';
      final version = m['version'] ?? '';
      if (status.contains('DONE') || status.contains('UP_TO_DATE')) {
        setState(() => _engineStatus = 'ENGINE v$version');
        _log('Engine update: $status (v$version)');
      } else {
        _log('Engine update status: $status');
      }
      return;
    }
    if (type == 'download') {
      final status = m['status'];
      final line = m['line'];
      final progress = (m['progress'] as num?)?.toDouble();
      if (status == 'started') {
        setState(() {
          _statusMessage = '[ENGINE] yt-dlp started...';
        });
        _log('Engine download started');
      } else if (status == 'done') {
        setState(() {
          _downloadProgress = 1.0;
          _statusMessage = '[ENGINE] finalizing...';
        });
        _log('Engine download finished (finalizing)');
      } else if (status == 'error') {
        setState(() {
          _isDownloading = false;
          _statusMessage = '[ERROR] ${m['error'] ?? 'download failed'}';
        });
        _log('Engine download error: ${m['error']}');
      } else {
        // live progress
        setState(() {
          if (progress != null) _downloadProgress = progress;
          if (line != null && line.isNotEmpty && line != 'null') {
            _statusMessage = line;
          }
        });
      }
    }
  }

  // ===== PERMISSIONS =====
  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  }

  // ===== SHARE INTENT =====
  void _initShareIntent() {
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final text = value.first.path ?? '';
          if (text.isNotEmpty) {
            setState(() {
              _urlController.text = text;
              _statusMessage = 'LINK INJECTED VIA SHARE-SHEET';
            });
            _startDownload();
          }
        }
      },
      onError: (err) => debugPrint('Share stream error: $err'),
    );

    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final text = value.first.path ?? '';
        if (text.isNotEmpty) {
          setState(() {
            _urlController.text = text;
            _statusMessage = 'LINK INJECTED VIA SHARE-SHEET';
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _startDownload());
        }
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  // ===== DOWNLOAD =====
  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _statusMessage = '[ERROR] Please enter a valid URL!');
      _log('ERROR: empty URL');
      return;
    }
    _log('Download request: $url (format: $_selectedFormat)');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = '[ENGINE] initializing yt-dlp...';
    });

    try {
      final dir = await _ytdl.invokeMethod<String>('defaultDir');
      final name = _fileNameController.text.trim();
      _log('Target dir: $dir');
      await _ytdl.invokeMethod('download', {
        'url': url,
        'dir': dir,
        'name': name,
        'format': _selectedFormat,
      });
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _statusMessage = '[SUCCESS] Saved to: $dir';
      });
      _log('SUCCESS: saved to $dir');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusMessage = '[ERROR] ${e.message ?? 'download failed'}';
      });
      _log('DOWNLOAD ERROR: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusMessage = '[ERROR] $e';
      });
      _log('DOWNLOAD ERROR: $e');
    }
  }

  Future<void> _cancelDownload() async {
    try {
      await _ytdl.invokeMethod('cancel');
      setState(() {
        _isDownloading = false;
        _statusMessage = '[ABORTED] Download cancelled';
      });
      _log('Download cancelled by user');
    } catch (e) {
      _log('Cancel error: $e');
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const GlitchText(
          text: '⚡ DEBDOWN+',
          style: TextStyle(
            color: kGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 20,
            shadows: [
              Shadow(color: Color(0x6639FF14), blurRadius: 12),
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(1, 2)),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                _engineStatus,
                style: const TextStyle(
                  fontSize: 9,
                  color: kPurple,
                  shadows: [Shadow(color: Color(0x66AF82FF), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const HackerBackground(),
          SafeArea(
            child: _currentIndex == 0
                ? _buildDownloaderTab()
                : _buildDevTab(),
          ),
          const IgnorePointer(child: CustomPaint(painter: ScanlinesPainter())),
        ],
      ),
      bottomNavigationBar: _buildGlassNav(),
    );
  }

  Widget _buildGlassNav() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x330A0F0A), Color(0x99000000)],
            ),
            border: Border(
              top: BorderSide(color: kGreen.withOpacity(0.25)),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            indicatorColor: kGreen.withOpacity(0.15),
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.download_outlined, color: Colors.grey),
                selectedIcon: const Icon(Icons.download, color: kGreen),
                label: 'Downloader',
              ),
              NavigationDestination(
                icon: const Icon(Icons.code, color: Colors.grey),
                selectedIcon: const Icon(Icons.code, color: kGreen),
                label: '[DEV]',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== DOWNLOADER TAB =====
  Widget _buildDownloaderTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          // Glitch banner
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlitchText(
                  text: '// YT-DLP ENGINE v1.2.0',
                  style: TextStyle(
                    color: kPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TikTok • Instagram • X • Facebook • SoundCloud • 1000+ situs\n'
                  'MP4 / MP3 • Playlist • Subtitle • Auto-Update',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // URL input
          _GlassField(
            controller: _urlController,
            label: 'Paste Link (YT / TikTok / IG / dll)',
            icon: Icons.link,
          ),
          const SizedBox(height: 12),

          // Format selector
          Row(
            children: [
              _FormatChip(
                label: 'MP4 (Video)',
                selected: _selectedFormat == 'mp4',
                onTap: () => setState(() => _selectedFormat = 'mp4'),
              ),
              const SizedBox(width: 10),
              _FormatChip(
                label: 'MP3 (Audio)',
                selected: _selectedFormat == 'mp3',
                onTap: () => setState(() => _selectedFormat = 'mp3'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filename
          _GlassField(
            controller: _fileNameController,
            label: 'Custom Filename (Optional)',
            icon: Icons.edit,
          ),
          const SizedBox(height: 16),

          // Download button
          _GlassButton(
            label: _isDownloading ? 'DOWNLOADING...' : 'START DOWNLOAD',
            icon: _isDownloading ? Icons.sync : Icons.bolt,
            color: kGreen,
            onTap: _isDownloading ? null : _startDownload,
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 10),
            _GlassButton(
              label: 'CANCEL',
              icon: Icons.stop,
              color: kRed,
              onTap: _cancelDownload,
            ),
          ],
          const SizedBox(height: 16),

          // Progress
          if (_isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 10,
                backgroundColor: Colors.black54,
                color: kGreen,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Status console (terminal)
          _TerminalConsole(
            message: _statusMessage,
            cursorCtrl: _cursorCtrl,
            isError: _statusMessage.startsWith('[ERROR]'),
          ),
        ],
      ),
    );
  }

  // ===== DEV TAB =====
  Widget _buildDevTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          const GlitchText(
            text: '[DEV] & DONATION PANEL',
            style: TextStyle(
              color: kPurple,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),

          // Profile
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ZoomImageView(
                  imagePath: 'assets/profile.png',
                  title: 'Developer Profile',
                ),
              ),
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kGreen, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x6639FF14), blurRadius: 24),
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/profile.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'debzroot (Developer)',
            style: TextStyle(
              color: kGreen,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Color(0x6639FF14), blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 28),

          // QR DANA
          const Text(
            'Traktir Kopi / Support Development',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ZoomImageView(
                  imagePath: 'assets/qr_dana.png',
                  title: 'QR DANA - Traktir Kopi',
                ),
              ),
            ),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPurple, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x44AF82FF), blurRadius: 20),
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/qr_dana.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap image to Zoom QR DANA',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 28),

          // SYSTEM LOGS
          GlassPanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const GlitchText(
                      text: '// SYSTEM LOGS',
                      style: TextStyle(
                        color: kPurple,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_logs.length} entries',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: _logs.isEmpty
                      ? const Text(
                          'No logs yet...',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        )
                      : ListView.builder(
                          reverse: true,
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[_logs.length - 1 - index];
                            final isError = log.contains('ERROR');
                            return Text(
                              log,
                              style: TextStyle(
                                color: isError ? kRed : kGreen,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // SHARE LOGS
          _GlassButton(
            label: 'SHARE LOGS.TXT',
            icon: Icons.ios_share,
            color: kGreen,
            onTap: _shareLogs,
          ),
          const SizedBox(height: 8),
          const Text(
            'Kirim file log ke developer untuk analisa error',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs() async {
    _log('Share logs requested (${_logs.length} entries)');
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/debdown_logs.txt');
      final header = 'DEBDOWN+ v1.2.0 - SYSTEM LOGS\n'
          'Generated: ${DateTime.now()}\n'
          'Device: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
          '${'=' * 40}\n\n';
      await file.writeAsString(header + _logs.join('\n'));
      _log('Logs written to ${file.path}');
      const channel = MethodChannel('debdown/ytdl');
      await channel.invokeMethod('shareFile', {
        'path': file.path,
        'text': 'DebDown+ v1.2.0 logs - please analyze',
      });
    } catch (e) {
      _log('SHARE LOGS ERROR: $e');
      setState(() => _statusMessage = '[ERROR] Failed to share logs: $e');
    }
  }
}

// ===== GLITCH TEXT (RGB split, CSS-style) =====
class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color ghostRed;
  final Color ghostCyan;
  final double intensity;

  const GlitchText({
    super.key,
    required this.text,
    required this.style,
    this.ghostRed = const Color(0xFFFF003C),
    this.ghostCyan = const Color(0xFF00FFFF),
    this.intensity = 1.0,
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> {
  final math.Random _rnd = math.Random();
  Timer? _timer;
  double _dx1 = 0, _dy1 = 0, _dx2 = 0, _dy2 = 0;
  bool _glitching = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      setState(() {
        _glitching = _rnd.nextDouble() < 0.4;
        if (_glitching) {
          final m = widget.intensity;
          _dx1 = (_rnd.nextDouble() * 6 - 3) * m;
          _dy1 = (_rnd.nextDouble() * 2 - 1) * m;
          _dx2 = (_rnd.nextDouble() * 6 - 3) * m;
          _dy2 = (_rnd.nextDouble() * 2 - 1) * m;
        } else {
          _dx1 = _dy1 = _dx2 = _dy2 = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // red ghost
        Transform.translate(
          offset: Offset(_dx1, _dy1),
          child: Opacity(
            opacity: _glitching ? 0.85 : 0,
            child: Text(
              widget.text,
              style: widget.style.copyWith(
                color: widget.ghostRed,
                shadows: const [Shadow(color: Color(0x66FF003C), blurRadius: 4)],
              ),
            ),
          ),
        ),
        // cyan ghost
        Transform.translate(
          offset: Offset(_dx2, _dy2),
          child: Opacity(
            opacity: _glitching ? 0.85 : 0,
            child: Text(
              widget.text,
              style: widget.style.copyWith(
                color: widget.ghostCyan,
                shadows: const [Shadow(color: Color(0x6600FFFF), blurRadius: 4)],
              ),
            ),
          ),
        ),
        // base
        Text(widget.text, style: widget.style),
      ],
    );
  }
}

// ===== GLASS PANEL (glassmorphism from base.css) =====
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double radius;
  final Color glowColor;
  final double blur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = kGlassBorder,
    this.radius = 14,
    this.glowColor = const Color(0x2239FF14),
    this.blur = 14,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x26FFFFFF), Color(0x0A000000)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 25,
                offset: const Offset(0, 15),
              ),
              BoxShadow(color: glowColor, blurRadius: 18),
              BoxShadow(
                color: Colors.white.withOpacity(0.08),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ===== GLASS INPUT FIELD =====
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: kGreen, fontSize: 14),
        decoration: InputDecoration(
          icon: Icon(icon, color: kGreenDim, size: 18),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// ===== FORMAT CHIP =====
class _FormatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderColor: selected ? kGreen : const Color(0x3339FF14),
          glowColor: selected ? const Color(0x3339FF14) : Colors.transparent,
          radius: 10,
          blur: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? kGreen : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? kGreen : Colors.grey,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== GLASS BUTTON =====
class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _GlassButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderColor: active ? color : Colors.grey.shade800,
        glowColor: active ? color.withOpacity(0.25) : Colors.transparent,
        radius: 12,
        blur: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? color : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 14,
                shadows: active
                    ? [Shadow(color: color.withOpacity(0.6), blurRadius: 8)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== TERMINAL CONSOLE =====
class _TerminalConsole extends StatelessWidget {
  final String message;
  final AnimationController cursorCtrl;
  final bool isError;

  const _TerminalConsole({
    required this.message,
    required this.cursorCtrl,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '❯',
            style: TextStyle(
              color: kCyan,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Color(0x6600FFFF), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? kRed : kGreen,
                fontSize: 12,
                height: 1.4,
                shadows: [
                  Shadow(
                    color: (isError ? kRed : kGreen).withOpacity(0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // blinking cursor
          FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.0).animate(cursorCtrl),
            child: Container(
              width: 8,
              height: 14,
              color: kGreen,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== BACKGROUND: grid + glow (port .parallax from base.css) =====
class HackerBackground extends StatelessWidget {
  const HackerBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kBg, Color(0xFF0A140A), kBg],
            ),
          ),
        ),
        const CustomPaint(painter: GridPainter()),
        Positioned(
          top: -90,
          right: -70,
          child: _GlowBlob(size: 320, color: const Color(0x3339FF14)),
        ),
        Positioned(
          bottom: -110,
          left: -90,
          child: _GlowBlob(size: 360, color: const Color(0x24AF82FF)),
        ),
        Positioned(
          top: 260,
          left: -60,
          child: _GlowBlob(size: 220, color: const Color(0x1A00FFFF)),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kGrid
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanlinesPainter extends CustomPainter {
  const ScanlinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1239FF14);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== ZOOM IMAGE VIEW =====
class ZoomImageView extends StatelessWidget {
  final String imagePath;
  final String title;

  const ZoomImageView({super.key, required this.imagePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(color: kGreen, fontSize: 15),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        color: const Color(0xFF050505),
        child: PhotoView(
          imageProvider: AssetImage(imagePath),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
      ),
    );
  }
}
