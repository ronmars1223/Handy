import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageUserPage extends StatefulWidget {
  @override
  _ManageUserPageState createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage> {
  final DatabaseReference _userRef =
      FirebaseDatabase.instance.ref('userprofiles');
  List<Map<String, dynamic>> _users = [];
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final snapshot = await _userRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      setState(() {
        _users = data.entries
            .map((entry) {
              final value = Map<String, dynamic>.from(entry.value);
              return {'key': entry.key, ...value};
            })
            .where((user) => user['userType'] == 'User') // Filter by userType
            .toList();

        _totalUsers = _users.length; // Update the total user count
      });
    }
  }

  Future<void> _updateUserStatus(String userKey, bool isDisabled) async {
    try {
      await _userRef.child(userKey).update({'disable': isDisabled});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDisabled
                ? 'User has been disabled successfully.'
                : 'User has been activated successfully.',
          ),
          backgroundColor: isDisabled ? Colors.red : Colors.green,
        ),
      );

      // Refresh user list
      _fetchUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Users: $_totalUsers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _users.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final bool isDisabled = user['disable'] ?? false;

                        return Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(
                                '${user['firstName']} ${user['lastName']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Email: ${user['email']}'),
                                Text(
                                  'Status: ${isDisabled ? 'Disabled' : 'Active'}',
                                  style: TextStyle(
                                    color:
                                        isDisabled ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isDisabled)
                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateUserStatus(user['key'], true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: Text(
                                      'Disable',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                if (isDisabled)
                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateUserStatus(user['key'], false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    child: Text(
                                      'Activate',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
