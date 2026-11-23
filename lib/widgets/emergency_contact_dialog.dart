import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';

/// Shows the add/edit dialog for the emergency contact and saves the
/// result through the store. Shared by the Caregiver settings card
/// and the Today screen's "Set emergency contact" button, so both
/// places edit the same stored contact.
///
/// Renders in the app's ONE selected language.
Future<void> showEmergencyContactDialog(
  BuildContext context,
  AppStore store,
) async {
  final existing = store.emergencyContact;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  String tr(String en, String ta) => store.tr(en, ta);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Emergency contact', 'அவசர தொடர்பு')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: tr('Name, e.g. Son / Daughter', 'பெயர்'),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          TextField(
            controller: phoneCtrl,
            decoration: InputDecoration(
              labelText: tr('Phone number', 'தொலைபேசி எண்'),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Cancel', 'ரத்து')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('Save', 'சேமி')),
        ),
      ],
    ),
  );
  if (saved != true) return;
  final name = nameCtrl.text.trim();
  final phone = phoneCtrl.text.trim();
  if (name.isEmpty || phone.isEmpty) {
    await store.setEmergencyContact(null);
  } else {
    await store.setEmergencyContact(
      EmergencyContact(name: name, phone: phone),
    );
  }
}
