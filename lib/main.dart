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
const kOrange = Color(0xFFFF8C00);
const kCyan = Color(0xFF00FFFF);
const kBg = Color(0xFF050505);
const kGrid = Color(0x4D145014); // rgba(20,80,20,0.3)
const kGlassBorder = Color(0x8039FF14);
const kMono = 'Saira'; // UI font (port dari base.css: font-family Saira)
const kMonoTerminal = 'monospace'; // khusus terminal console / logs

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
    with TickerProviderStateMixin {
  static const _ytdl = MethodChannel('debdown/ytdl');
  static const _ytdlEvents = EventChannel('debdown/ytdl/progress');

  int _currentIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  String _selectedFormat = 'mp4';

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'SYSTEM READY [v1.3.0]';
  bool _showComplete = false;
  Timer? _completeTimer;
  String _engineStatus = 'ENGINE INIT...';
  final List<String> _logs = [];
  late final AnimationController _cursorCtrl;
  late final AnimationController _glowCtrl; // BUAT KEDIP FOTO (efek.txt)

  StreamSubscription<dynamic>? _shareSub;
  StreamSubscription<dynamic>? _ytdlSub;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _log('App started v1.3.0');
    _requestPermissions();
    _initEngine();
    _initShareIntent();
    _ytdlSub = _ytdlEvents.receiveBroadcastStream().listen(_onEngineEvent);
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _shareSub?.cancel();
    _ytdlSub?.cancel();
    _cursorCtrl.dispose();
    _glowCtrl.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // ===== LOGGING =====
  void _log(String message) {
    final ts = DateTime.now().toString().substring(0, 19);
    _logs.add('[$ts] $message');
    if (_logs.length > 200) _logs.removeAt(0);
    debugPrint('[DebDown+] $message');
  }

  // ===== ENGINE (DebDown+ native) =====
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
          _statusMessage = '⚡DebDown+ downloading...';
        });
        _log('Engine download started');
      } else if (status == 'done') {
        setState(() {
          _downloadProgress = 1.0;
          _statusMessage = '⚡DebDown+ finalizing...';
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
      _statusMessage = '⚡DebDown+ initializing...';
      _showComplete = false;
    });
    _completeTimer?.cancel();

    try {
      final dir = await _ytdl.invokeMethod<String>('defaultDir');
      _log('Target dir: $dir');
      await _ytdl.invokeMethod('download', {
        'url': url,
        'dir': dir,
        'name': '',
        'format': _selectedFormat,
      });
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _statusMessage = '[SUCCESS] Saved to: $dir';
        _showComplete = true;
      });
      _completeTimer?.cancel();
      _completeTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _showComplete = false);
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

  // ===== TUTORIAL POPUP =====
  void _showTutorial() {
    _log('Tutorial opened');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TutorialSheet(),
    );
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
    return Stack(
      children: [
        SingleChildScrollView(
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
                  text: '// ⚡DEBDOWN+ ENGINE v1.3.0',
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

          // CARA PAKAI button
          _GlassButton(
            label: '⚡ CARA PAKAI',
            icon: Icons.help_outline,
            color: kCyan,
            onTap: _showTutorial,
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

          // Hacker progress panel
          if (_isDownloading) ...[
            HackerDownloadPanel(
              progress: _downloadProgress,
              statusLine: _statusMessage,
              isError: _statusMessage.startsWith('[ERROR]'),
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
        ),
        if (_showComplete) const DownloadCompleteOverlay(),
      ],
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
      final header = 'DEBDOWN+ v1.3.0 - SYSTEM LOGS\n'
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

// ===== HACKER DOWNLOAD PANEL (loading effect) =====
class HackerDownloadPanel extends StatefulWidget {
  final double progress;
  final String statusLine;
  final bool isError;

  const HackerDownloadPanel({
    super.key,
    required this.progress,
    required this.statusLine,
    this.isError = false,
  });

  @override
  State<HackerDownloadPanel> createState() => _HackerDownloadPanelState();
}

class _HackerDownloadPanelState extends State<HackerDownloadPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;
  late final AnimationController _bars;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _bars = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweep.dispose();
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isError ? kRed : kGreen;
    final pct = (widget.progress.clamp(0.0, 1.0) * 100).round();
    return GlassPanel(
      borderColor: color,
      glowColor: color.withOpacity(0.25),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          const Positioned.fill(child: _CornerBrackets()),
          Row(
            children: [
              // Progress ring
              SizedBox(
                width: 92,
                height: 92,
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (_, __) => CustomPaint(
                    painter: _ProgressRingPainter(
                      progress: widget.progress,
                      sweep: _sweep.value,
                      isError: widget.isError,
                    ),
                    child: Center(
                      child: Text(
                        '$pct%',
                        style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: color,
                          shadows: [
                            Shadow(color: color.withOpacity(0.7), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: kYellow, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          widget.isError
                              ? 'DOWNLOAD FAILED'
                              : 'DOWNLOADING',
                          style: TextStyle(
                            fontFamily: kMono,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: color,
                            shadows: [
                              Shadow(color: color.withOpacity(0.5), blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _EqualizerBars(ctrl: _bars, color: color),
                    const SizedBox(height: 10),
                    // Live status line
                    Text(
                      widget.statusLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kMonoTerminal,
                        fontSize: 9,
                        color: Colors.grey.shade400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double sweep; // 0..1 rotating
  final bool isError;

  _ProgressRingPainter({
    required this.progress,
    required this.sweep,
    required this.isError,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final color = isError ? kRed : kGreen;
    final p = progress.clamp(0.0, 1.0);

    // track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.black.withOpacity(0.6),
    );

    // glow underlay
    canvas.drawArc(
      rect,
      -math.pi / 2,
      p * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = color.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // progress arc with animated gradient
    canvas.drawArc(
      rect,
      -math.pi / 2,
      p * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            color.withOpacity(0.3),
            color,
            Colors.white,
            color,
            color.withOpacity(0.3),
          ],
          transform: GradientRotation(sweep * 2 * math.pi),
        ).createShader(rect),
    );

    // rotating tick marks
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withOpacity(0.35);
    for (var i = 0; i < 12; i++) {
      final a = sweep * 2 * math.pi + i * (2 * math.pi / 12);
      final r1 = radius - 8;
      final r2 = radius - 5;
      canvas.drawLine(
        Offset(center.dx + r1 * math.cos(a), center.dy + r1 * math.sin(a)),
        Offset(center.dx + r2 * math.cos(a), center.dy + r2 * math.sin(a)),
        tickPaint,
      );
    }

    // head dot
    final headAngle = -math.pi / 2 + p * 2 * math.pi;
    final head = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );
    canvas.drawCircle(head, 8, Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(head, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress || old.sweep != sweep || old.isError != isError;
}

class _EqualizerBars extends StatelessWidget {
  final Animation<double> ctrl;
  final Color color;

  const _EqualizerBars({required this.ctrl, required this.color});

  @override
  Widget build(BuildContext context) {
    const bars = 6;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(bars, (i) {
            final phase = i * 0.9;
            final h = 6 +
                14 *
                    (0.5 +
                        0.5 *
                            math.sin(
                                ctrl.value * 2 * math.pi * 2 + phase));
            return Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.5), blurRadius: 4),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    Widget corner(Alignment alignment, bool top, bool left) {
      final c = kGreen.withOpacity(0.5);
      return Align(
        alignment: alignment,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            border: Border(
              top: top ? BorderSide(color: c, width: 2) : BorderSide.none,
              left: left ? BorderSide(color: c, width: 2) : BorderSide.none,
              bottom: !top ? BorderSide(color: c, width: 2) : BorderSide.none,
              right: !left ? BorderSide(color: c, width: 2) : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        corner(Alignment.topLeft, true, true),
        corner(Alignment.topRight, true, false),
        corner(Alignment.bottomLeft, false, true),
        corner(Alignment.bottomRight, false, false),
      ],
    );
  }
}

// ===== DOWNLOAD COMPLETE OVERLAY =====
class DownloadCompleteOverlay extends StatefulWidget {
  const DownloadCompleteOverlay({super.key});

  @override
  State<DownloadCompleteOverlay> createState() =>
      _DownloadCompleteOverlayState();
}

class _DownloadCompleteOverlayState extends State<DownloadCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            final flash =
                t < 0.25 ? (t / 0.25) : (1 - (t - 0.25) / 0.75).clamp(0.0, 1.0);
            final scale = t < 0.3
                ? 0.4 + 1.4 * (t / 0.3)
                : 1.8 - 0.8 * ((t - 0.3) / 0.25).clamp(0.0, 1.0);
            final fade = t > 0.6 ? (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0) : 1.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                // green flash
                Container(color: kGreen.withOpacity(0.18 * flash)),
                // particles burst
                CustomPaint(painter: _ParticlesPainter(t: t)),
                // center content
                Center(
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kGreen.withOpacity(0.12),
                              border: Border.all(color: kGreen, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: kGreen.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: kGreen,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const GlitchText(
                            text: '⚡ DOWNLOAD COMPLETE',
                            intensity: 1.4,
                            style: TextStyle(
                              fontFamily: kMono,
                              color: kGreen,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Color(0x9939FF14),
                                  blurRadius: 14,
                                ),
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 2,
                                  offset: Offset(1, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'FILE SAVED TO DOWNLOAD/DEBDOWN+',
                            style: TextStyle(
                              fontFamily: kMonoTerminal,
                              fontSize: 9,
                              letterSpacing: 1,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double t; // 0..1

  _ParticlesPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t > 0.55) return;
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi;
      final dist = 60 + 140 * (t / 0.55);
      final p = Offset(
        center.dx + dist * math.cos(a),
        center.dy + dist * math.sin(a),
      );
      final alpha = (1 - t / 0.55) * 0.7;
      canvas.drawCircle(p, 2.5, Paint()..color = kGreen.withOpacity(alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => old.t != t;
}

// ===== TUTORIAL SHEET (Cara Pakai) =====
class TutorialSheet extends StatefulWidget {
  const TutorialSheet({super.key});

  @override
  State<TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<TutorialSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kGreen.withOpacity(0.25),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x330A1A0A), Color(0xE6050505)],
                      ),
                      border: Border.all(color: kGreen.withOpacity(0.5)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // drag handle
                        Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const GlitchText(
                          text: '⚡ CARA PAKAI DEBDOWN+',
                          intensity: 1.3,
                          style: TextStyle(
                            fontFamily: kMono,
                            color: kGreen,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(
                                color: Color(0x6639FF14),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gampang banget, 2 cara aja 👇',
                          style: TextStyle(
                            fontFamily: kMono,
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              children: [
                                _TutorialStep(
                                  anim: _ctrl,
                                  index: 0,
                                  icon: Icons.copy,
                                  color: kYellow,
                                  title: 'CARA 1 • COPY & PASTE',
                                  lines: [
                                    'Buka app TikTok / IG / YT, ketuk ikon SHARE '
                                        'di video yang mau diambil',
                                    'Pilih COPY LINK, atau langsung "Copy" dari '
                                        'kolom share',
                                    'Buka ⚡DebDown+ → tempel (paste) link di '
                                        'kolom di atas 👆',
                                  ],
                                ),
                                _TutorialStep(
                                  anim: _ctrl,
                                  index: 1,
                                  icon: Icons.ios_share,
                                  color: kGreen,
                                  title: 'CARA 2 • SHARE LANGSUNG',
                                  lines: [
                                    'Di app video, ketuk SHARE',
                                    'Pilih ⚡DebDown+ di daftar share sheet',
                                    'Auto! Link langsung masuk & download jalan '
                                        'sendiri 🚀',
                                  ],
                                ),
                                _TutorialStep(
                                  anim: _ctrl,
                                  index: 2,
                                  icon: Icons.tune,
                                  color: kPurple,
                                  title: 'PILIH FORMAT',
                                  lines: [
                                    'MP4 = video + suara (paling umum)',
                                    'MP3 = audio aja, buat dengerin doang 🎧',
                                    'Bisa ganti-ganti kapan aja sebelum download',
                                  ],
                                ),
                                _TutorialStep(
                                  anim: _ctrl,
                                  index: 3,
                                  icon: Icons.download_done,
                                  color: kCyan,
                                  title: 'TEKAN START DOWNLOAD 🔥',
                                  lines: [
                                    'Tunggu progress sampai 100%',
                                    'File otomatis masuk folder '
                                        'Download/DebDown+',
                                    'Support YouTube, TikTok, IG, X, FB, '
                                        'SoundCloud & 1000+ situs!',
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _GlassButton(
                            label: 'SIAP, GAS!',
                            icon: Icons.bolt,
                            color: kGreen,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  final Animation<double> anim;
  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;

  const _TutorialStep({
    required this.anim,
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    // staggered slide-in per step
    final start = 0.08 + index * 0.16;
    final end = start + 0.3;
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = ((anim.value - start) / (end - start)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: color.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.12),
                      border: Border.all(color: color.withOpacity(0.6)),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: kMono,
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '▸ ',
                                  style: TextStyle(
                                    color: color.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontFamily: kMono,
                                      color: Colors.grey.shade300,
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
