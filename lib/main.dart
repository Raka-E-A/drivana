import 'home_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color navy = Color(0xFF142F70);
const Color blue = Color(0xFF176BC0);
const Color cyan = Color(0xFF31B6F5);

const String adminEmail = 'admin@drivana.com';

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ytlipojntjzrpztgigcz.supabase.co',
    publishableKey: 'sb_publishable_JkQD-O1nhLI6e90XERggMQ_sE70DuKY',
  );

  runApp(const DrivanaApp());
}

class DrivanaApp extends StatelessWidget {
  const DrivanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drivana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
      ),
      home: const AuthPage(),
    );
  }
}

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  AuthMode _mode = AuthMode.login;
  String _role = 'customer';
  bool _obscurePassword = true;
  bool _loading = false;
  bool _mitraLogin = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    FocusScope.of(context).unfocus();

    setState(() {
      _mode = mode;
      _mitraLogin = false;
      _role = 'customer';
      _formKey.currentState?.reset();
      _name.clear();
      _email.clear();
      _phone.clear();
      _password.clear();
    });
  }

  Future<void> _showMessage(String title, String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Email atau password salah.';
        case 'user_already_exists':
          return 'Email tersebut sudah terdaftar. Silakan masuk.';
        case 'email_not_confirmed':
          return 'Email belum diverifikasi. Periksa kotak masuk email Anda.';
        case 'weak_password':
          return 'Password terlalu lemah. Gunakan password yang lebih kuat.';
        default:
          return error.message;
      }
    }

    return 'Terjadi kesalahan koneksi atau sistem. Silakan coba lagi.';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);

    try {
      if (_mode == AuthMode.register) {
        // REGISTRASI CUSTOMER ATAU MITRA
        final response = await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'nama': _name.text.trim(),
            'noTelp': _phone.text.trim(),
            'role': _role,
          },
        );

        if (!mounted) return;

        if (response.session == null) {
          await _showMessage(
            'Registrasi berhasil',
            'Akun berhasil dibuat. Silakan periksa email untuk '
                'verifikasi jika diminta, kemudian masuk ke Drivana.',
          );

          if (mounted) {
            _switchMode(AuthMode.login);
          }
        } else {
          await _showMessage(
            'Registrasi berhasil',
            'Selamat datang di Drivana! Akun Anda telah dibuat.',
          );

          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeRouter(),
            ),
          );
        }
      } else {
        // LOGIN: CUSTOMER, MITRA, ATAU ADMIN
        final response = await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );

        if (!mounted) return;

        final user = response.user;

        if (user == null) {
          await _showMessage(
            'Login gagal',
            'Email atau password salah.',
          );
          return;
        }

        final email = user.email?.trim().toLowerCase();
        final configuredAdminEmail = adminEmail.trim().toLowerCase();

        // Role Admin wajib ditetapkan melalui app_metadata
        // oleh pengelola tepercaya di Supabase.
        final appRole = user.appMetadata['role']?.toString();

        // Admin dikenali otomatis berdasarkan email.
        // Namun, email saja tidak memberikan hak akses Admin.
        if (email == configuredAdminEmail) {
          if (appRole != 'admin') {
            await supabase.auth.signOut();

            if (!mounted) return;

            await _showMessage(
              'Akun Admin belum dikonfigurasi',
              'Email ini cocok dengan email Admin, tetapi role Admin '
                  'belum ditetapkan pada app_metadata di Supabase.',
            );
            return;
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeRouter(),
            ),
          );
          return;
        }

        // Akun dengan role admin tidak menggunakan jalur Customer/Mitra.
        if (appRole == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HomeRouter(),
            ),
          );
          return;
        }

        // Role Customer/Mitra saat ini mengikuti metadata registrasi.
        final userRole = user.userMetadata?['role']?.toString();
        final actualRole = userRole == 'mitra' ? 'mitra' : 'customer';

        if (_mitraLogin && actualRole != 'mitra') {
          await supabase.auth.signOut();

          if (!mounted) return;

          await _showMessage(
            'Akun bukan Mitra',
            'Silakan gunakan akun yang terdaftar sebagai Mitra.',
          );
          return;
        }

        if (!_mitraLogin && actualRole != 'customer') {
          await supabase.auth.signOut();

          if (!mounted) return;

          await _showMessage(
            'Gunakan menu login yang sesuai',
            'Akun ini terdaftar sebagai ${actualRole.toUpperCase()}.',
          );
          return;
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const HomeRouter(),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      await _showMessage(
        _mode == AuthMode.login ? 'Login gagal' : 'Registrasi gagal',
        _friendlyError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      await _showMessage(
        'Lupa Password',
        'Masukkan alamat email yang valid pada kolom Email terlebih dahulu.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await supabase.auth.resetPasswordForEmail(email);

      if (!mounted) return;

      await _showMessage(
        'Periksa Email Anda',
        'Jika email terdaftar, instruksi pemulihan password akan dikirim '
            'ke alamat tersebut.',
      );
    } catch (error) {
      if (!mounted) return;
      await _showMessage('Gagal', _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == AuthMode.register;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [navy, Color(0xFF174B94), blue, cyan],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _brandIcon(),
                      const SizedBox(height: 18),
                      Text(
                        isRegister ? 'Buat Akun Baru' : 'Selamat\nDatang!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isRegister
                            ? 'Daftar sekarang, gratis!'
                            : 'Masuk ke akun kamu',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 26),

                      if (isRegister) ...[
                        _label('Nama lengkap'),
                        _input(
                          controller: _name,
                          hint: 'Masukkan nama',
                          icon: Icons.person_outline,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Nama wajib diisi.'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                      ],

                      _label('Email'),
                      _input(
                        controller: _email,
                        hint: 'Masukkan email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)) {
                            return 'Masukkan alamat email yang valid.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      if (isRegister) ...[
                        _label('No. HP'),
                        _input(
                          controller: _phone,
                          hint: '08xxxxxxxxxx',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ -]'),
                            ),
                          ],
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 9) {
                              return 'Masukkan nomor telepon yang valid.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _label('Daftar sebagai'),
                        Row(
                          children: [
                            Expanded(
                              child: _roleButton(
                                'customer',
                                'Customer',
                                Icons.person_outline,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _roleButton(
                                'mitra',
                                'Mitra',
                                Icons.directions_car_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      _label('Password'),
                      _input(
                        controller: _password,
                        hint: isRegister
                            ? 'Buat password (min. 8 karakter)'
                            : 'Masukkan password',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';

                          if (password.isEmpty) {
                            return 'Password wajib diisi.';
                          }

                          if (isRegister && password.length < 8) {
                            return 'Password minimal 8 karakter.';
                          }

                          return null;
                        },
                      ),

                      if (!isRegister) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: const Text(
                              'Lupa Password?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: blue,
                            disabledBackgroundColor: Colors.white70,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 21,
                                  width: 21,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isRegister ? 'Daftar Sekarang' : 'Masuk',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),

                      if (!isRegister) ...[
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.white30),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'atau',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.white30),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() => _mitraLogin = true);
                                  },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withAlpha(35),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: _mitraLogin
                                    ? Colors.white
                                    : Colors.white24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: const Text('Masuk Sebagai Mitra'),
                          ),
                        ),
                        if (_mitraLogin)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () {
                                setState(() => _mitraLogin = false);
                              },
                              child: const Text(
                                'Kembali ke login Customer',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],

                      const SizedBox(height: 18),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isRegister
                                  ? 'Sudah punya akun? '
                                  : 'Belum punya akun? ',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _switchMode(
                                isRegister
                                    ? AuthMode.login
                                    : AuthMode.register,
                              ),
                              child: Text(
                                isRegister ? 'Masuk' : 'Daftar',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _brandIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Icon(
        Icons.directions_car_filled_outlined,
        color: Colors.white,
        size: 27,
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withAlpha(32),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        errorMaxLines: 2,
        errorStyle: const TextStyle(color: Color(0xFFFFD5D5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Colors.white70),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFFFA8A8)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFFFA8A8)),
        ),
      ),
    );
  }

  Widget _roleButton(String value, String label, IconData icon) {
    final selected = _role == value;

    return InkWell(
      onTap: () => setState(() => _role = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withAlpha(58)
              : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomePage extends StatelessWidget {
  final String role;

  const WelcomePage({
    super.key,
    this.role = 'customer',
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (role) {
      'admin' => 'Admin',
      'mitra' => 'Mitra',
      _ => 'Customer',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivana'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () async {
              await supabase.auth.signOut();

              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => const AuthPage(),
                ),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_car_filled,
                size: 64,
                color: blue,
              ),
              const SizedBox(height: 16),
              Text(
                'Selamat datang di Drivana!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Login berhasil sebagai $roleLabel.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Halaman ini merupakan placeholder. Dashboard '
                'Customer, Mitra, dan Admin akan dibuat pada tahap berikutnya.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
