import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'root_shell.dart';
import 'sign_in_screen.dart';

/// Decides what to show based on auth state: signed-in landlords go
/// straight to the app; everyone else sees the sign-in screen (which
/// also offers a "Continue as Guest" anonymous-auth option).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const RootShell();
        }
        return const SignInScreen();
      },
    );
  }
}
