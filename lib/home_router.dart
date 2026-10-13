
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_home_page.dart';
import 'mitra/mitra_home_page.dart';
import 'user/user_home_page.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Silakan login kembali.')),
      );
    }

    // Admin harus berasal dari app_metadata.
    final appRole = user.appMetadata['role']
        ?.toString()
        .toLowerCase();

    // Role User/Mitra berasal dari metadata registrasi.
    final userRole = user.userMetadata?['role']
        ?.toString()
        .toLowerCase();

    if (appRole == 'admin') {
      return const AdminHomePage();
    }

    if (userRole == 'mitra') {
      return const MitraHomePage();
    }

    return const UserHomePage();
  }
}
