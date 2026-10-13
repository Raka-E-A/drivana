
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivana Admin'),
        backgroundColor: const Color(0xFF102A43),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();

              if (!context.mounted) return;

              Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Dashboard Admin',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Selamat datang, $email'),
          const SizedBox(height: 24),
          const _AdminCard(
            icon: Icons.people,
            title: 'Kelola Pengguna',
            description: 'Kelola akun pengguna Drivana.',
          ),
          const _AdminCard(
            icon: Icons.store,
            title: 'Kelola Mitra',
            description: 'Pantau dan kelola mitra.',
          ),
          const _AdminCard(
            icon: Icons.receipt_long,
            title: 'Kelola Pesanan',
            description: 'Pantau transaksi dan pesanan.',
          ),
          const _AdminCard(
            icon: Icons.bar_chart,
            title: 'Statistik',
            description: 'Ringkasan aktivitas Drivana.',
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        leading: Icon(
          icon,
          size: 30,
          color: const Color(0xFF1677FF),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title belum diimplementasikan.'),
            ),
          );
        },
      ),
    );
  }
}
