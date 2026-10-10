import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
const NotificationsScreen({super.key});

@override
State<NotificationsScreen> createState() =>
_NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
final List<Map<String, dynamic>> notifications = [
{
'title': 'Welcome to LIFELINK AI',
'message': 'Emergency alerts and updates will appear here.',
'time': 'Now',
'read': false,
'icon': Icons.notifications_active,
},
];

void markAsRead(int index) {
setState(() {
notifications[index]['read'] = true;
});
}

void clearNotifications() {
setState(() {
notifications.clear();
});
}

@override
Widget build(BuildContext context) {
final unreadCount =
notifications.where((notification) => !notification['read']).length;

return Scaffold(
appBar: AppBar(
title: const Text('Notifications'),
actions: [
if (notifications.isNotEmpty)
IconButton(
tooltip: 'Clear all',
icon: const Icon(Icons.delete_outline),
onPressed: clearNotifications,
),
],
),
body: Column(
children: [
if (unreadCount > 0)
Padding(
padding: const EdgeInsets.all(16),
child: Align(
alignment: Alignment.centerLeft,
child: Text(
'$unreadCount unread notification(s)',
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 16,
),
),
),
),
Expanded(
child: notifications.isEmpty
? const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.notifications_off_outlined,
size: 64,
color: Colors.grey,
),
SizedBox(height: 12),
Text(
'No notifications yet',
style: TextStyle(fontSize: 18),
),
SizedBox(height: 6),
Text('New alerts will appear here.'),
],
),
)
    : ListView.builder(
itemCount: notifications.length,
itemBuilder: (context, index) {
final notification = notifications[index];

return Card(
margin: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 6,
),
color: notification['read']
? null
    : Colors.red.withValues(alpha: 0.06),
child: ListTile(
leading: CircleAvatar(
backgroundColor: Colors.red.withValues(
alpha: 0.1,
),
child: Icon(
notification['icon'] as IconData,
color: Colors.red,
),
),
title: Text(
notification['title'] as String,
style: TextStyle(
fontWeight: notification['read']
? FontWeight.normal
    : FontWeight.bold,
),
),
subtitle: Text(
'${notification['message']}\n'
'${notification['time']}',
),
isThreeLine: true,
trailing: notification['read']
? const Icon(
Icons.check_circle_outline,
color: Colors.grey,
)
    : const Icon(
Icons.circle,
color: Colors.red,
size: 12,
),
onTap: () => markAsRead(index),
),
);
},
),
),
],
),
);
}
}
