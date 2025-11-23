import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart'; // <-- import HomePage
import 'services/auth_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Aplikasi Absensi',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
           elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
  ),
        ),
        home: LoginPage(),
        routes: {
          '/login': (_) =>  LoginPage(), // <-- daftarkan
          '/home' : (_) => const HomePage(),  // opsional, kalau mau pushNamed('/home')
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
