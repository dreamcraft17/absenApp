import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/employee_model.dart';

class EmployeeDetailPage extends StatefulWidget {
  final String employeeId;

  const EmployeeDetailPage({super.key, required this.employeeId});

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  Employee? _employee;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployeeDetail();
  }

  Future<void> _loadEmployeeDetail() async {
    final result = await ApiService.getEmployeeDetail(widget.employeeId);
    if (mounted) {
      setState(() {
        _loading = false;
        if (result['success'] == true) {
          _employee = Employee.fromMap(result['data']);
        }
      });
    }
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Detail'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employee == null
              ? const Center(child: Text('Employee not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.black,
                                child: Text(
                                  _employee!.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _employee!.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_employee!.position),
                                    Text(_employee!.branch),
                                    const SizedBox(height: 8),
                                    Chip(
                                      label: Text(
                                        _employee!.status.toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: _employee!.status == 'active' 
                                          ? Colors.green 
                                          : Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stats
                      const Text(
                        'Statistics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        children: [
                          _buildStatCard('Check-Ins', _employee!.stats?.totalCheckins ?? 0, Colors.blue),
                          _buildStatCard('Check-Outs', _employee!.stats?.totalCheckouts ?? 0, Colors.green),
                          _buildStatCard('Absences', _employee!.stats?.totalAbsences ?? 0, Colors.orange),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Contact Info
                      const Text(
                        'Contact Information',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildInfoRow('Phone', _employee!.phone),
                              _buildInfoRow('Email', _employee!.email),
                              _buildInfoRow('Join Date', _employee!.joinDate),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}