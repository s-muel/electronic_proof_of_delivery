import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import 'services/waybill_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await WaybillService.init();

  runApp(const EPodApp());
}

class EPodApp extends StatelessWidget {
  const EPodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BAJ E-POD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}