import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

// ---------------------------------------------------------------------
// Fill these in from your Supabase project: Project Settings -> API
// ---------------------------------------------------------------------
const String supabaseUrl = 'https://uopxvteeippnxlddzovf.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvcHh2dGVlaXBwbnhsZGR6b3ZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwNTk3MzksImV4cCI6MjA5NzYzNTczOX0._NgMJFK8MkJhEU6p3C1ocdXMSVZgZL88vlQY-7RVc-8';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const RentManagerApp());
}

class RentManagerApp extends StatelessWidget {
  const RentManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rent Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        const maxWidth = 480.0;
        final cappedWidth =
            mq.size.width > maxWidth ? maxWidth : mq.size.width;
        return Container(
          color: const Color(0xFFE9EBEE),
          alignment: Alignment.topCenter,
          child: MediaQuery(
            data: mq.copyWith(size: Size(cappedWidth, mq.size.height)),
            child: SizedBox(
              width: cappedWidth,
              height: mq.size.height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
