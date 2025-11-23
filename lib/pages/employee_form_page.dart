import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/employee_model.dart';

class EmployeeFormPage extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormPage({super.key, this.employee});

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _branch = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _joinDate = TextEditingController();
  String _status = 'active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    if (e != null) {
      _name.text = e.name;
      _branch.text = e.branch;
      _position.text = e.position;
      _department.text = e.department ?? '';
      _phone.text = e.phone;
      _email.text = e.email;
      _joinDate.text = e.joinDate;
      _status = e.status;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      _joinDate.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEdit = widget.employee != null;
    Map<String, dynamic> res;

    if (isEdit) {
      res = await ApiService.updateEmployee(
        employeeId: widget.employee!.id,
        name: _name.text.trim(),
        branch: _branch.text.trim(),
        position: _position.text.trim(),
        department: _department.text.trim().isEmpty ? null : _department.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        status: _status.trim(),
      );
    } else {
      res = await ApiService.createEmployee(
        name: _name.text.trim(),
        branch: _branch.text.trim(),
        position: _position.text.trim(),
        department: _department.text.trim().isEmpty ? null : _department.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        joinDate: _joinDate.text.trim(),
        status: _status.trim(),
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Employee updated' : 'Employee added'),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Something went wrong'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _input(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text, bool required = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
        readOnly: onTap != null,
        onTap: onTap,
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
    final isEdit = widget.employee != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Employee' : 'Add Employee',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _input('Name', _name, required: true),
            _input('Branch', _branch),
            _input('Position', _position),
            _input('Department', _department),
            _input('Phone', _phone, required: true, type: TextInputType.phone),
            _input('Email', _email, type: TextInputType.emailAddress),
            _input('Join Date', _joinDate, onTap: _pickDate),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isEdit ? 'Update Employee' : 'Create Employee'),
            ),
          ],
        ),
      ),
    );
  }
}
