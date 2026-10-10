
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
const EmergencyContactsScreen({super.key});

@override
State<EmergencyContactsScreen> createState() =>
_EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
extends State<EmergencyContactsScreen> {
static const String storageKey = 'emergency_contacts';

bool isLoading = true;
List<Map<String, String>> personalContacts = [];

// Fixed emergency numbers: these cannot be deleted by users.
final List<Map<String, String>> officialContacts = [
{
'name': 'National Emergency Helpline',
'phone': '112',
'description': 'Police, fire and other emergencies',
},
{
'name': 'Fire Services',
'phone': '101',
'description': 'Fire and rescue',
},
{
'name': 'Ambulance',
'phone': '108',
'description': 'Ambulance service, where available',
},
];

@override
void initState() {
super.initState();
loadContacts();
}

// LOAD PERSONAL CONTACTS
Future<void> loadContacts() async {
try {
final prefs = await SharedPreferences.getInstance();
final savedData = prefs.getString(storageKey);

if (savedData != null) {
final List<dynamic> decoded = jsonDecode(savedData);

personalContacts = decoded.map((item) {
return Map<String, String>.from(item);
}).toList();
}
} catch (e) {
personalContacts = [];
}

if (!mounted) return;

setState(() {
isLoading = false;
});
}

// SAVE PERSONAL CONTACTS
Future<void> saveContacts() async {
final prefs = await SharedPreferences.getInstance();

await prefs.setString(
storageKey,
jsonEncode(personalContacts),
);
}

// CALL A NUMBER
Future<void> callNumber(String phone) async {
final uri = Uri(
scheme: 'tel',
path: phone,
);

try {
final launched = await launchUrl(
uri,
mode: LaunchMode.externalApplication,
);

if (!launched && mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Unable to open the phone dialer.'),
),
);
}
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Unable to open the phone dialer.'),
),
);
}
}

// ADD A PERSONAL CONTACT
Future<void> showAddContactDialog() async {
final nameController = TextEditingController();
final phoneController = TextEditingController();
final formKey = GlobalKey<FormState>();

final result = await showDialog<bool>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: const Text('Add Emergency Contact'),
content: Form(
key: formKey,
child: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextFormField(
controller: nameController,
textCapitalization: TextCapitalization.words,
decoration: const InputDecoration(
labelText: 'Contact name',
prefixIcon: Icon(Icons.person_outline),
border: OutlineInputBorder(),
),
validator: (value) {
if (value == null || value.trim().isEmpty) {
return 'Enter the contact name';
}
return null;
},
),
const SizedBox(height: 14),
TextFormField(
controller: phoneController,
keyboardType: TextInputType.phone,
decoration: const InputDecoration(
labelText: 'Phone number',
prefixIcon: Icon(Icons.phone_outlined),
border: OutlineInputBorder(),
hintText: 'Enter phone number',
),
validator: (value) {
final phone = value?.trim() ?? '';
final digits =
phone.replaceAll(RegExp(r'\D'), '');

if (digits.length < 7 || digits.length > 15) {
return 'Enter a valid phone number';
}

return null;
},
),
],
),
),
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext, false);
},
child: const Text('Cancel'),
),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
foregroundColor: Colors.white,
),
onPressed: () {
if (formKey.currentState!.validate()) {
Navigator.pop(dialogContext, true);
}
},
child: const Text('Save Contact'),
),
],
);
},
);

if (result == true) {
final name = nameController.text.trim();
final phone = phoneController.text.trim();

personalContacts.add({
'name': name,
'phone': phone,
});

await saveContacts();

if (mounted) {
setState(() {});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Emergency contact saved successfully.'),
),
);
}
}

nameController.dispose();
phoneController.dispose();
}

// DELETE A PERSONAL CONTACT
Future<void> deleteContact(int index) async {
final contact = personalContacts[index];

final confirm = await showDialog<bool>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: const Text('Delete Contact?'),
content: Text(
'Remove ${contact['name']} from your emergency contacts?',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext, false);
},
child: const Text('Cancel'),
),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
foregroundColor: Colors.white,
),
onPressed: () {
Navigator.pop(dialogContext, true);
},
child: const Text('Delete'),
),
],
);
},
);

if (confirm != true) return;

setState(() {
personalContacts.removeAt(index);
});

await saveContacts();

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Contact deleted.'),
),
);
}

// CONTACT CARD
Widget contactCard({
required String name,
required String phone,
required String description,
required bool isOfficial,
VoidCallback? onDelete,
}) {
return Card(
color: Colors.white,
elevation: 1,
margin: const EdgeInsets.only(bottom: 12),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
side: BorderSide(
color: Colors.grey.shade200,
),
),
child: Padding(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 10,
),
child: Row(
children: [
CircleAvatar(
backgroundColor: isOfficial
? Colors.red.withValues(alpha: 0.10)
    : Colors.blue.withValues(alpha: 0.10),
child: Icon(
isOfficial ? Icons.shield_outlined : Icons.person_outline,
color: isOfficial ? Colors.red : Colors.blue,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
name,
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 14,
),
),
const SizedBox(height: 4),
Text(
phone,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 3),
Text(
description,
style: TextStyle(
color: Colors.grey.shade600,
fontSize: 12,
),
),
if (isOfficial) ...[
const SizedBox(height: 5),
const Text(
'Official number',
style: TextStyle(
color: Colors.green,
fontSize: 11,
fontWeight: FontWeight.w600,
),
),
],
],
),
),
const SizedBox(width: 4),
Column(
mainAxisSize: MainAxisSize.min,
children: [
IconButton(
tooltip: 'Call $phone',
onPressed: () => callNumber(phone),
icon: const Icon(
Icons.call,
color: Colors.green,
),
),
if (!isOfficial)
IconButton(
tooltip: 'Delete contact',
onPressed: onDelete,
icon: const Icon(
Icons.delete_outline,
color: Colors.red,
),
),
],
),
],
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF7F8FA),
appBar: AppBar(
title: const Text('Emergency Contacts'),
backgroundColor: Colors.red,
foregroundColor: Colors.white,
),
floatingActionButton: FloatingActionButton.extended(
onPressed: showAddContactDialog,
backgroundColor: Colors.red,
foregroundColor: Colors.white,
icon: const Icon(Icons.person_add_alt_1),
label: const Text('Add Contact'),
),
body: isLoading
? const Center(
child: CircularProgressIndicator(),
)
    : ListView(
padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
children: [
// INTRODUCTION
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.red.withValues(alpha: 0.07),
borderRadius: BorderRadius.circular(16),
),
child: const Row(
children: [
Icon(
Icons.health_and_safety_outlined,
color: Colors.red,
size: 34,
),
SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Stay Prepared',
style: TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),
SizedBox(height: 5),
Text(
'Quickly call emergency services or '
'people you trust.',
style: TextStyle(fontSize: 13),
),
],
),
),
],
),
),

const SizedBox(height: 24),

// FIXED OFFICIAL NUMBERS
const Text(
'Official Emergency Numbers',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 12),

...officialContacts.map((contact) {
return contactCard(
name: contact['name']!,
phone: contact['phone']!,
description: contact['description']!,
isOfficial: true,
);
}),

const SizedBox(height: 20),

// PERSONAL CONTACTS
Row(
children: [
const Expanded(
child: Text(
'My Emergency Contacts',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
),
Text(
'${personalContacts.length} saved',
style: TextStyle(
color: Colors.grey.shade600,
fontSize: 12,
),
),
],
),
const SizedBox(height: 12),

if (personalContacts.isEmpty)
Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: Colors.grey.shade200,
),
),
child: const Column(
children: [
Icon(
Icons.contacts_outlined,
size: 42,
color: Colors.grey,
),
SizedBox(height: 10),
Text(
'No personal contacts added yet.',
textAlign: TextAlign.center,
style: TextStyle(
fontWeight: FontWeight.w600,
),
),
SizedBox(height: 5),
Text(
'Tap "Add Contact" to save a family member '
'or trusted person.',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey,
fontSize: 13,
),
),
],
),
)
else
...List.generate(personalContacts.length, (index) {
final contact = personalContacts[index];

return contactCard(
name: contact['name'] ?? 'Unknown',
phone: contact['phone'] ?? '',
description: 'Personal contact',
isOfficial: false,
onDelete: () => deleteContact(index),
);
}),

const SizedBox(height: 20),

const Text(
'Emergency calls depend on phone service and local '
'availability. Use official emergency services '
'responsibly.',
style: TextStyle(
color: Colors.grey,
fontSize: 12,
),
textAlign: TextAlign.center,
),
],
),
);
}
}
