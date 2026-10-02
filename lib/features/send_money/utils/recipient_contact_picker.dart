import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// One contact the user chose in the system picker (no address-book permission).
class PickedRecipientContact {
  const PickedRecipientContact({this.name, this.phone});

  final String? name;
  final String? phone;
}

/// Opens the OS contact picker. Android uses `ACTION_PICK` on a phone URI so
/// the app never needs `READ_CONTACTS`. iOS uses `CNContactPickerViewController`.
class RecipientContactPicker {
  RecipientContactPicker._();

  static const _androidChannel =
      MethodChannel('com.truepay.safaritap/contact_picker');

  static Future<PickedRecipientContact?> pick() async {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final result = await _androidChannel.invokeMapMethod<String, dynamic>(
          'pick',
        );
        if (result == null) return null;
        return PickedRecipientContact(
          name: _nonEmpty(result['name']),
          phone: _nonEmpty(result['phone']),
        );
      case TargetPlatform.iOS:
        final contact = await FlutterContacts.native.showPicker(
          properties: {ContactProperty.name, ContactProperty.phone},
        );
        if (contact == null) return null;
        final phone = contact.phones.isEmpty
            ? null
            : (contact.phones.first.normalizedNumber ??
                contact.phones.first.number);
        return PickedRecipientContact(
          name: _nonEmpty(contact.displayName),
          phone: _nonEmpty(phone),
        );
      default:
        return null;
    }
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
