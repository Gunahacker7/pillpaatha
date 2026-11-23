import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../theme.dart';

/// Setup aid for this sideloaded demo build: App Check runs on the
/// debug provider, and its token must be registered once in the
/// Firebase console (App Check → Apps → Manage debug tokens) before
/// Gemini calls are accepted. This tile shows the token so it can
/// be copied across. Shown on the Scan screen and in Profile.
class AppCheckTokenTile extends StatelessWidget {
  const AppCheckTokenTile({super.key, required this.store});

  final AppStore store;

  String _tr(String en, String ta) => store.tr(en, ta);

  Future<void> _showToken(BuildContext context) async {
    String tokenText;
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      tokenText = token ??
          'No token was returned. Restart the app, keep the phone '
              'online, and try again.';
    } catch (e) {
      tokenText = 'Could not get a token: $e';
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr('App Check setup token', 'App Check டோக்கன்')),
        content: SingleChildScrollView(
          child: SelectableText(tokenText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr('Close', 'மூடு')),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: tokenText));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(_tr('Copy', 'நகலெடு')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.key_outlined, size: 18),
      title: Text(
        _tr(
          'App Check setup token',
          'App Check டோக்கன் — தொட்டு நகலெடுக்கவும்',
        ),
        style: const TextStyle(fontSize: 13, color: PillTheme.inkSoft),
      ),
      onTap: () => _showToken(context),
    );
  }
}
