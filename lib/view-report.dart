import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ViewReportsPage extends StatelessWidget {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Fetches all reports from Firebase.
  Future<List<Map<String, dynamic>>> _fetchReports() async {
    try {
      final snapshot = await _dbRef.child('reports').get();
      if (snapshot.exists) {
        final reports = (snapshot.value as Map)
            .values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return reports;
      }
    } catch (e) {
      print('Error fetching reports: $e');
    }
    return [];
  }

  /// Fetches user details (first and last name) based on the user ID.
  Future<Map<String, String>> _fetchUserDetails(String userId) async {
    try {
      final snapshot = await _dbRef.child('userprofiles/$userId').get();
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        return {
          'firstName': userData['firstName'] ?? 'Unknown',
          'lastName': userData['lastName'] ?? 'User',
        };
      }
    } catch (e) {
      print('Error fetching user details for $userId: $e');
    }
    return {'firstName': 'Unknown', 'lastName': 'User'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View All Reports'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(
              child: Text('No reports available.'),
            );
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final reportedBy = report['reportedBy'] ?? 'Unknown';

              return FutureBuilder<Map<String, String>>(
                future: _fetchUserDetails(reportedBy),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userDetails = userSnapshot.data ??
                      {
                        'firstName': 'Unknown',
                        'lastName': 'User',
                      };

                  return Card(
                    margin: const EdgeInsets.all(12.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provider: ${report['providerName'] ?? 'Unknown'}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reported By: ${userDetails['firstName']} ${userDetails['lastName']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reason: ${report['reason'] ?? 'No reason provided.'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Timestamp: ${report['timestamp'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
