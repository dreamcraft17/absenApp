import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/home_menu_config_service.dart';

class HomeMenuSettingsPage extends StatefulWidget {
  const HomeMenuSettingsPage({super.key});

  @override
  State<HomeMenuSettingsPage> createState() => _HomeMenuSettingsPageState();
}

class _HomeMenuSettingsPageState extends State<HomeMenuSettingsPage> {
  String _selectedRole = 'staff';
  bool _loading = true;
  Map<String, bool> _config = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cfg = await HomeMenuConfigService.loadForRole(_selectedRole);
      if (!mounted) return;
      setState(() {
        _config = cfg;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal load konfigurasi: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await HomeMenuConfigService.saveForRole(_selectedRole, _config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Konfigurasi berhasil disimpan'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal menyimpan: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _checkAll() {
    setState(() {
      for (var item in HomeMenuItems.all) {
        _config[item.key] = true;
      }
    });
  }

  void _uncheckAll() {
    setState(() {
      for (var item in HomeMenuItems.all) {
        _config[item.key] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;
    final roleLC = (user?.role ?? 'staff').toLowerCase();

    // Hanya Superadmin yang boleh akses
    if (roleLC != 'superadmin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Home Menu Settings')),
        body: const Center(
          child: Text('Anda tidak memiliki akses ke halaman ini.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Menu Settings'),
        elevation: 0,
      ),
      body: _loading && _config.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Role',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: HomeMenuConfigService.supportedRoles
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r),
                                ),
                              )
                              .toList(),
                          onChanged: _loading
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  setState(() {
                                    _selectedRole = v;
                                  });
                                  _loadConfig();
                                },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              onPressed: _loading ? null : _checkAll,
                              icon: Icons.done_all,
                              label: 'Check All',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              onPressed: _loading ? null : _uncheckAll,
                              icon: Icons.clear_all,
                              label: 'Uncheck All',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Menu Items List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: HomeMenuItems.all.length,
                    itemBuilder: (context, index) {
                      final item = HomeMenuItems.all[index];
                      final value = _config[item.key] ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: value
                                ? Colors.green.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          value: value,
                          onChanged: _loading
                              ? null
                              : (v) {
                                  setState(() {
                                    _config[item.key] = v;
                                  });
                                },
                          activeColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Save Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveConfig,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_outlined, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Simpan Konfigurasi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                if (_loading)
                  const LinearProgressIndicator(minHeight: 2),
              ],
            ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}