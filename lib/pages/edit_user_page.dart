import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditUserPage({super.key, required this.user});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _branch;
  late final TextEditingController _position;
  late final TextEditingController _password; // optional
  String _role = 'staff';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name     = TextEditingController(text: (u['name'] ?? '').toString());
    _email    = TextEditingController(text: (u['email'] ?? '').toString());
    _branch   = TextEditingController(text: (u['branch'] ?? '').toString());
    _position = TextEditingController(text: (u['position'] ?? '').toString());
    _password = TextEditingController();
    _role     = (u['role'] ?? 'staff').toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _branch.dispose();
    _position.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

final res = await ApiService.updateUser(
  id: (widget.user['user_id'] ?? widget.user['id']).toString(),
  name: _name.text.trim(),
  email: _email.text.trim(),
  branch: _branch.text.trim(),
  position: _position.text.trim(),
  role: _role.trim(),
  password: _password.text.trim().isEmpty ? null : _password.text.trim(),
);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Failed')),
      );
    }
  }

  Widget _input(String label, TextEditingController c, {bool required = false, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit User', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _input('Name', _name, required: true),
            _input('Email', _email, required: true, type: TextInputType.emailAddress),
            _input('Branch', _branch),
            _input('Position', _position),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: const [
                DropdownMenuItem(value: 'staff', child: Text('staff')),
                DropdownMenuItem(value: 'manager', child: Text('manager')),
                DropdownMenuItem(value: 'admin', child: Text('admin')),
                DropdownMenuItem(value: 'superadmin', child: Text('superadmin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'staff'),
            ),
            const SizedBox(height: 8),
            _input('New Password (optional)', _password),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes'),
            )
          ],
        ),
      ),
    );
  }
}
