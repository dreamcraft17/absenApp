import 'dart:async';
import 'dart:io';
import 'package:ee_employee/services/auth_service.dart';
import 'package:ee_employee/services/database_service.dart';
import 'package:ee_employee/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AttendancePage extends StatefulWidget {
  /// 'masuk' (check-in) | 'pulang' (check-out)
  final String type;
  const AttendancePage({super.key, required this.type});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  String _location = 'Getting location...';
  String _time = '';
  String _date = '';
  File? _image;
  bool _isLoading = false;

  // Auto refresh / retry flags
  bool _gotLocation = false;
  bool _permDeniedForever = false;
  Timer? _retryTimer;
  Timer? _clockTimer;
  int _retryCount = 0;
  static const int _maxRetry = 8;
  static const Duration _retryEvery = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
    _takePicture();
    _startRetryIfNeeded();
    _startClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
      _startRetryIfNeeded();
    }
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _getCurrentTime();
    });
  }

  void _refreshAll() {
    _getCurrentTime();
    _getCurrentLocation();
  }

  void _getCurrentTime() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    setState(() {
      _time = '$hh:$mm:$ss';
      _date = '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final Position position = await _locationService.getCurrentLocation();
      final String address = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _location = address;
        _gotLocation = true;
        _permDeniedForever = false;
      });
      _retryTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      final isForever = errStr.contains('ditolak secara permanen') || errStr.contains('denied forever');
      setState(() {
        _location = 'Failed to get location: $e';
        _gotLocation = false;
        _permDeniedForever = isForever;
      });
    }
  }

  void _startRetryIfNeeded() {
    if (_gotLocation) {
      _retryTimer?.cancel();
      return;
    }
    _retryTimer?.cancel();
    _retryCount = 0;
    _retryTimer = Timer.periodic(_retryEvery, (t) async {
      if (!mounted) return;
      if (_gotLocation || _retryCount >= _maxRetry) {
        t.cancel();
        return;
      }
      _retryCount++;
      await _getCurrentLocation();
    });
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await Geolocator.openAppSettings();
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      if (image != null) {
        if (!mounted) return;
        setState(() => _image = File(image.path));
      }
    } catch (_) {}
  }

  Future<bool> _confirmOverwriteIfNeeded(String userId) async {
    final list = await _databaseService.getAttendances(userId);
    final today = DateTime.now().toString().split(' ').first;
    Map<String, dynamic>? existingToday;
    for (final e in list) {
      final t = (e['type'] ?? '').toString().toLowerCase();
      final d = (e['date'] ?? '').toString();
      if (t == widget.type.toLowerCase() && d == today) {
        existingToday = e;
      }
    }
    if (existingToday == null) return true;

    if (!mounted) return false;
    final isCheckIn = widget.type.toLowerCase() == 'masuk';
    final actionText = isCheckIn ? 'Check-In' : 'Check-Out';
    final prevTime = (existingToday['time'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.black, size: 28),
            const SizedBox(width: 12),
            const Text('Overwrite Record?'),
          ],
        ),
        content: Text(
          prevTime.isNotEmpty
              ? 'You already recorded $actionText at $prevTime today.\nDo you want to overwrite with the new time?'
              : 'You already recorded $actionText today.\nDo you want to overwrite with the new time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
            ),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submitAttendance() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Please take a photo first'),
            ],
          ),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!_gotLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.white),
              SizedBox(width: 12),
              Text('Location not available'),
            ],
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.user;

      final proceed = await _confirmOverwriteIfNeeded(user!.id);
      if (!proceed) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await _databaseService.saveAttendance(
        userId: user.id,
        type: widget.type,
        time: _time.substring(0, 5), // HH:MM only
        location: _location,
        image: _image!,
      );

      if (!mounted) return;
      final actionText = widget.type.toLowerCase() == 'masuk' ? 'Check-In' : 'Check-Out';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('$actionText recorded successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.type.toLowerCase() == 'masuk';
    final title = isCheckIn ? 'Check-In' : 'Check-Out';
    final primaryColor = isCheckIn ? Colors.blue : Colors.black;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Saving $title...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isTablet ? 24 : 16),
              child: Column(
                children: [
                  // Time Display - Big & Beautiful
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCheckIn
                            ? [Colors.white, Colors.black]
                            : [Colors.black, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isCheckIn ? Icons.login : Icons.logout,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _time,
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _date,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Location Status
                  if (!_gotLocation)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_off, color: Colors.red.shade700, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Location Required',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _permDeniedForever
                                ? 'Location permission is permanently denied. Please enable it in settings to continue.'
                                : 'Location is unavailable. Please allow location permission to record attendance.',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openLocationSettings,
                              icon: const Icon(Icons.settings),
                              label: const Text('Open Settings'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.green.shade600,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Current Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Photo Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Selfie Photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Photo Preview
                        _image != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      height: isTablet ? 400 : 300,
                                      width: double.infinity,
                                      color: Colors.grey.shade100,
                                      child: Image.file(
                                        _image!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade500,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Ready',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                height: isTablet ? 400 : 300,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No photo taken',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                        const SizedBox(height: 16),

                        // Retake Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _takePicture,
                            icon: Icon(_image != null ? Icons.refresh : Icons.camera_alt),
                            label: Text(_image != null ? 'Retake Photo' : 'Take Photo'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryColor),
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCheckIn ? Icons.login : Icons.logout,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Submit $title',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}