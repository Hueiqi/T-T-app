import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth/auth.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F1F1F), SpotifyColors.black],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: SpotifyColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.graphic_eq,
                        color: SpotifyColors.black, size: 52),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Millions of songs.\nFree on Spotify.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => auth.login(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpotifyColors.green,
                        foregroundColor: SpotifyColors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Log in with Spotify'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A Spotify Premium account is required for full playback.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        auth.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
