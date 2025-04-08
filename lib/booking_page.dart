import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class BookedUsersPage extends StatefulWidget {
  const BookedUsersPage({Key? key}) : super(key: key);

  @override
  _BookedUsersPageState createState() => _BookedUsersPageState();
}

class _BookedUsersPageState extends State<BookedUsersPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = true; // Loading indicator
  bool _showCompleted = false; // Track if we're showing completed jobs
  List<Map<String, dynamic>> _bookedUsers = []; // List to store booked users
  List<Map<String, dynamic>> _completedJobs =
      []; // List to store completed jobs

  @override
  void initState() {
    super.initState();
    _fetchBookedUsers();
  }

  void _processBooking(Map<String, dynamic> booking) async {
    try {
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      final String providerId = FirebaseAuth.instance.currentUser!.uid;

      // Extract and clean userID
      String? userID = booking['userID'];
      if (userID == null) {
        throw Exception('User ID not found in bookedUsers.');
      }

      // Clean the userID
      if (userID.contains('_')) {
        userID = userID.split('_').first;
      }

      // Locate the `book_jobs` for the user
      final bookJobsSnapshot = await dbRef
          .child('userprofiles')
          .child(userID)
          .child('book_jobs')
          .get();
      if (!bookJobsSnapshot.exists) {
        throw Exception('No book_jobs found for cleaned userID: $userID.');
      }

      // Filter and find jobs associated with the current provider
      final Map<dynamic, dynamic> bookJobs =
          Map<dynamic, dynamic>.from(bookJobsSnapshot.value as Map);
      String? matchedJobKey;
      bookJobs.forEach((jobID, jobData) {
        final Map<String, dynamic> job = Map<String, dynamic>.from(jobData);
        if (job['providerId'] == providerId && job['status'] != 'Ongoing') {
          matchedJobKey = jobID;
        }
      });

      if (matchedJobKey == null) {
        throw Exception(
            'No jobs needing processing for provider: $providerId under userID: $userID.');
      }

      // Update the status of the matching job
      await dbRef
          .child('userprofiles')
          .child(userID)
          .child('book_jobs')
          .child(matchedJobKey!)
          .update({'status': 'Ongoing'});

      // Update the status in `bookedUsers` under the provider
      final bookedUsersSnapshot = await dbRef
          .child('userprofiles')
          .child(providerId)
          .child('bookedUsers')
          .get();

      if (!bookedUsersSnapshot.exists) {
        throw Exception(
            'No bookedUsers data found under provider: $providerId.');
      }

      // Find the correct key to update
      final Map<dynamic, dynamic> bookedUsers =
          Map<dynamic, dynamic>.from(bookedUsersSnapshot.value as Map);
      String? bookedUserKey;
      bookedUsers.forEach((key, value) {
        final Map<String, dynamic> userBooking =
            Map<String, dynamic>.from(value);
        if (userBooking['userId'] == userID) {
          bookedUserKey = key;
        }
      });

      if (bookedUserKey == null) {
        throw Exception(
            'No matching bookedUser found for userID: $userID under provider: $providerId.');
      }

      // Update the status for the specific booking
      await dbRef
          .child('userprofiles')
          .child(providerId)
          .child('bookedUsers')
          .child(bookedUserKey!)
          .update({'status': 'Ongoing'});

      // Update the local state for the UI
      setState(() {
        booking['status'] = 'Ongoing';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Booking status for Job ID $matchedJobKey updated to Ongoing!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stacktrace) {
      print('Error processing booking: $e');
      print('Stacktrace: $stacktrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchBookedUsers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      // Fetch booked users under 'userprofiles/{providerId}/bookedUsers'
      final snapshot = await _dbRef
          .child('userprofiles')
          .child(user.uid)
          .child('bookedUsers')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _bookedUsers = data.entries.map((entry) {
            final value = Map<String, dynamic>.from(entry.value as Map);

            return {
              'userID': entry.key, // Include the userID
              'fullName': value['fullName'] ?? 'No Full Name',
              'email': value['userEmail'] ?? 'No Email',
              'name': value['name'] ?? 'No Name',
              'address': value['address'] ?? 'No Address',
              'contactNumber': value['contactNumber'] ?? 'No Contact Number',
              'selected_schedule': value['selected_schedule'] ?? 'No Schedule',
              'status': value['status'] ?? '',
            };
          }).toList();
        });
      } else {
        setState(() {
          _bookedUsers = [];
        });
      }

      // Fetch completed jobs under 'userprofiles/{providerId}/job_completed'
      final completedSnapshot = await _dbRef
          .child('userprofiles')
          .child(user.uid)
          .child('job_completed')
          .get();

      if (completedSnapshot.exists) {
        final data = completedSnapshot.value as Map<dynamic, dynamic>;

        setState(() {
          _completedJobs = data.entries.map((entry) {
            final value = Map<String, dynamic>.from(entry.value as Map);

            return {
              'fullName': value['fullName'] ?? 'No Full Name',
              'address': value['address'] ?? 'No Address',
              'contactNumber': value['contactNumber'] ?? 'No Contact Number',
              'email': value['userEmail'] ?? 'No Email',
              'status': value['status'] ?? '',
            };
          }).toList();
        });
      } else {
        setState(() {
          _completedJobs = [];
        });
      }
    } catch (e) {
      print('Error fetching booked users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching booked users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'Completed',
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted; // Toggle between views
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _showCompleted
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Completed Jobs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Booked Users',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _showCompleted
                      ? _completedJobs.isEmpty
                          ? const Center(
                              child: Text(
                                'No completed jobs yet.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              itemCount: _completedJobs.length,
                              itemBuilder: (context, index) {
                                final job = _completedJobs[index];
                                return _buildCompletedJobCard(job);
                              },
                            )
                      : _bookedUsers.isEmpty
                          ? const Center(
                              child: Text(
                                'No users have booked yet.',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              itemCount: _bookedUsers.length,
                              itemBuilder: (context, index) {
                                final user = _bookedUsers[index];
                                return _buildBookedUserCard(user);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookedUserCard(Map<String, dynamic> user) {
    String formattedSchedule = 'No Schedule';
    if (user['selected_schedule'] != null &&
        user['selected_schedule'].isNotEmpty) {
      try {
        final DateTime date = DateTime.parse(user['selected_schedule']);
        formattedSchedule =
            '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}-${date.year}';
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    String status = user['status']?.toString().trim().toLowerCase() ?? '';
    bool isCompleted = status == 'completed';
    bool isOngoingOrProcess = status == 'ongoing' || status == 'process';

    Color statusColor = isCompleted
        ? Colors.grey
        : isOngoingOrProcess
            ? Colors.blue
            : Colors.green;
    String buttonText = isCompleted
        ? 'Completed'
        : isOngoingOrProcess
            ? 'Ongoing'
            : 'Process';
    bool isButtonDisabled = isOngoingOrProcess || isCompleted;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 3,
              offset: Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['fullName'] ?? 'No Full Name',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.email, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      user['email'] ?? 'No Email',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.phone, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      user['contactNumber'] ?? 'No Contact Number',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      formattedSchedule,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      user['address'] ?? 'No Address',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status.capitalize(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: isButtonDisabled
                      ? null
                      : () {
                          _processBooking(user);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted
                        ? Colors.grey
                        : isButtonDisabled
                            ? Colors.grey
                            : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedJobCard(Map<String, dynamic> job) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 3,
              offset: Offset(2, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job['fullName'] ?? 'No Full Name',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  job['address'] ?? 'No Address',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  job['contactNumber'] ?? 'No Contact Number',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  job['email'] ?? 'No Email',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
