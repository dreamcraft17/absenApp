import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _saving = false;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _branch = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  String _role = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: 'profile-photo',
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image_rounded,
                                size: 80, color: Colors.white54),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // tombol tutup
                Positioned(
                  top: 40,
                  right: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // (opsional) tombol hapus langsung dari viewer
                if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  Positioned(
                    top: 40,
                    left: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.7),
                      child: IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteAvatar();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final res = await ApiService.getProfile(int.parse(user.id.toString()));
    if (!mounted) return;

    if (res['success'] == true) {
      final d = Map<String, dynamic>.from(res['data'] ?? {});
      _name.text = (d['name'] ?? '').toString();
      _email.text = (d['email'] ?? '').toString();
      _branch.text = (d['branch'] ?? '').toString();
      _position.text = (d['position'] ?? '').toString();
      _department.text = (d['department'] ?? '').toString();
      _role = (d['role'] ?? '').toString();
      final rawAvatar = (d['avatar_url'] ?? '').toString();
      _avatarUrl = (rawAvatar.isEmpty || rawAvatar == 'null') ? null : rawAvatar;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to load profile'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final u = auth.user;
    if (u == null) return;

    final res = await ApiService.updateProfile(
      userId: int.parse(u.id.toString()),
      name: _name.text.trim(),
      email: _email.text.trim(),
      branch: _branch.text.trim(),
      position: _position.text.trim(),
      department: _department.text.trim().isEmpty ? null : _department.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile updated successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Failed to update'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndUpload() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final u = auth.user;
    if (u == null) return;

    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Change Profile Picture",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose your preferred method",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  _imageOption(
                    context,
                    icon: Icons.camera_alt_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    label: "Take Photo",
                    subtitle: "Use your camera",
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _imageOption(
                    context,
                    icon: Icons.photo_library_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                    ),
                    label: "Choose from Gallery",
                    subtitle: "Pick from your photos",
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),

                  // === REMOVE PHOTO (show only if avatar exists) ===
                  if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _imageOption(
                      context,
                      icon: Icons.delete_forever_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFef5350), Color(0xFFd32f2f)],
                      ),
                      label: "Remove Photo",
                      subtitle: "Delete current profile picture",
                      onTap: () async {
                        Navigator.pop(context);
                        await _deleteAvatar();
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  _imageOption(
                    context,
                    icon: Icons.close_rounded,
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                    ),
                    label: "Cancel",
                    subtitle: "Go back",
                    onTap: () => Navigator.pop(context, null),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (picked == null) return;
    final file = File(picked.path);

    final res = await ApiService.uploadProfilePicture(
      userId: int.parse(u.id.toString()),
      userName: _name.text.trim(),
      branch: _branch.text.trim(),
      file: file,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile picture updated'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Upload failed'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteAvatar() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final u = auth.user;
    if (u == null) return;

    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada foto profil untuk dihapus')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus foto profil?'),
        content: const Text('Tindakan ini akan menghapus foto profil kamu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Hapus'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await ApiService.deleteProfilePicture(
      userId: int.parse(u.id.toString()),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _avatarUrl = null);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Foto profil berhasil dihapus'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'Gagal menghapus foto'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Profile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _save,
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header Section with Avatar
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
                                    _showFullImage(_avatarUrl!);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('No profile picture available'),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Hero(
                                    tag: 'profile-photo',
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                          ? NetworkImage(_avatarUrl!)
                                          : null,
                                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                          ? Icon(
                                              Icons.person_rounded,
                                              size: 50,
                                              color: Colors.grey.shade400,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // tombol kamera (upload)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: GestureDetector(
                                onTap: _pickAndUpload,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            // tombol hapus (muncul kalau ada avatar)
                            if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: GestureDetector(
                                  onTap: _deleteAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _name.text.isEmpty ? 'User Name' : _name.text,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.purple.shade400],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _role.isEmpty ? 'No Role' : _role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _modernInput(
                          label: 'Full Name',
                          controller: _name,
                          icon: Icons.person_outline_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 16),
                        _modernInput(
                          label: 'Email Address',
                          controller: _email,
                          icon: Icons.email_outlined,
                          type: TextInputType.emailAddress,
                          required: true,
                        ),
                        const SizedBox(height: 16),
                        _modernInput(
                          label: 'Branch',
                          controller: _branch,
                          icon: Icons.business_outlined,
                        ),
                        const SizedBox(height: 16),
                        _modernInput(
                          label: 'Position',
                          controller: _position,
                          icon: Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _modernInput(
                          label: 'Department',
                          controller: _department,
                          icon: Icons.apartment_outlined,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _modernInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool required = false,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.blue.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _imageOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
