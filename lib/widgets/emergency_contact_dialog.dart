import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models.dart';

/// Shows the add/edit dialog for the emergency contact and saves the
/// result through the store. Shared by the Caregiver settings card
/// and the Today screen's "Set emergency contact" button, so both
/// places edit the same stored contact.
Future<void> showEmergencyContactDialog(
  BuildContext context,
  AppStore store,
) async {
  final existing = store.emergencyContact;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Emergency contact · அவசர தொடர்பு'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name, e.g. Son / Daughter · பெயர்',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone number · தொலைபேசி எண்',
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save'),
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
