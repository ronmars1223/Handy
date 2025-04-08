import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderJobsPage extends StatefulWidget {
  final String providerId;
  final String providerName;
  final Map<String, dynamic> selectedJob;

  ProviderJobsPage({
    required this.providerId,
    required this.providerName,
    required this.selectedJob,
  });

  @override
  _ProviderJobsPageState createState() => _ProviderJobsPageState();
}

class _ProviderJobsPageState extends State<ProviderJobsPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isBooked = false;
  DateTime? _selectedDate; // Holds the selected date for booking

  @override
  void initState() {
    super.initState();
    _checkIfJobIsBooked();
  }

  Future<void> _checkIfJobIsBooked() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final String uniqueJobKey =
          '${user.uid}_${widget.selectedJob['jobTitle'].toString().replaceAll(' ', '_')}';

      final userBookingsRef =
          _dbRef.child('userprofiles/${user.uid}/book_jobs/$uniqueJobKey');
      final snapshot = await userBookingsRef.get();

      setState(() {
        _isBooked = snapshot.exists;
      });
    } catch (e) {
      print('Error checking booking status: $e');
    }
  }

  /// Show Date Picker and Book Job
  void _pickDateAndBookJob() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)), // 1 year range
    );

    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate; // Save the selected date
      });
      _bookJob(selectedDate); // Proceed with booking
    }
  }

  void _reportUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to log in to report a user.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController reportController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report User'),
          content: TextField(
            controller: reportController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for Reporting',
              hintText: 'Describe the issue...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final reason = reportController.text.trim();

                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report reason cannot be empty.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final reportData = {
                    'providerId': widget.providerId,
                    'providerName': widget.providerName,
                    'reportedBy': user.uid,
                    'reason': reason,
                    'timestamp': DateTime.now().toIso8601String(),
                  };

                  await _dbRef.child('reports').push().set(reportData);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit report: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _bookJob(DateTime selectedDate) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to log in to book a job.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final DateTime now = DateTime.now();
      DatabaseReference userProfileRef =
          _dbRef.child('userprofiles/${user.uid}');
      final userProfileSnapshot = await userProfileRef.get();
      if (!userProfileSnapshot.exists) {
        throw Exception('User profile not found.');
      }

      final userData =
          Map<String, dynamic>.from(userProfileSnapshot.value as Map);
      final String fullName =
          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
      final String address = userData['address'] ?? 'N/A';
      final String contactNumber = userData['contactNumber'] ?? 'N/A';

      // Create the unique key using userId and jobTitle
      final String sanitizedJobTitle =
          widget.selectedJob['jobTitle'].toString().replaceAll(' ', '_');
      final String uniqueJobKey = '${user.uid}_$sanitizedJobTitle';

      // Data for the booking
      final bookingData = {
        'jobTitle': widget.selectedJob['jobTitle'] ?? 'No Title',
        'about': widget.selectedJob['about'] ?? 'No Description',
        'experience': widget.selectedJob['experience'] ?? 'N/A',
        'expertise': widget.selectedJob['expertise'] ?? 'N/A',
        'status': 'Pending',
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'userId': user.uid,
        'userEmail': user.email ?? 'N/A',
        'fullName': fullName,
        'address': address,
        'contactNumber': contactNumber,
        'selected_schedule': selectedDate.toIso8601String(),
        'timestamp': now.toIso8601String(),
      };

      // Save booking under the user profile with unique key
      DatabaseReference userBookingsRef =
          _dbRef.child('userprofiles/${user.uid}/book_jobs');
      await userBookingsRef.child(uniqueJobKey).set(bookingData);

      // Save booking under the provider's booked users with unique key
      DatabaseReference providerBookedUsersRef =
          _dbRef.child('userprofiles/${widget.providerId}/bookedUsers');
      await providerBookedUsersRef.child(uniqueJobKey).set({
        ...bookingData,
        'userName': fullName,
      });

      setState(() {
        _isBooked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to book job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelBooking() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final String sanitizedJobTitle =
          widget.selectedJob['jobTitle'].toString().replaceAll(' ', '_');
      final String uniqueJobKey = '${user.uid}_$sanitizedJobTitle';

      // Remove the booking from the user's `book_jobs` node
      DatabaseReference userBookingsRef =
          _dbRef.child('userprofiles/${user.uid}/book_jobs');
      await userBookingsRef.child(uniqueJobKey).remove();

      // Remove the booking from the provider's `bookedUsers` node
      DatabaseReference providerBookedUsersRef =
          _dbRef.child('userprofiles/${widget.providerId}/bookedUsers');
      await providerBookedUsersRef.child(uniqueJobKey).remove();

      setState(() {
        _isBooked = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking canceled successfully!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewProviderProfile() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final providerSnapshot =
          await _dbRef.child('userprofiles/${widget.providerId}').get();

      Navigator.pop(context); // Close the loading dialog

      if (providerSnapshot.exists) {
        final providerDetails =
            Map<String, dynamic>.from(providerSnapshot.value as Map);

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('${widget.providerName} - Profile'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoTile('Email', providerDetails['email']),
                    _buildInfoTile('Contact', providerDetails['contactNumber']),
                    _buildInfoTile('Address', providerDetails['address']),
                    if (providerDetails['coordinates'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoTile(
                              'Latitude',
                              providerDetails['coordinates']['latitude']
                                  ?.toString()),
                          _buildInfoTile(
                              'Longitude',
                              providerDetails['coordinates']['longitude']
                                  ?.toString()),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the profile dialog
                    _viewProviderFeedback(providerDetails['feedbacks']);
                  },
                  child: const Text('View Feedback'),
                ),
              ],
            );
          },
        );
      } else {
        _showSnackbar('Provider details not found.', isError: true);
      }
    } catch (e) {
      Navigator.pop(context); // Close the loading dialog
      _showSnackbar('Failed to load provider details: $e', isError: true);
    }
  }

  void _viewProviderFeedback(dynamic feedbackData) {
    if (feedbackData == null || (feedbackData as Map).isEmpty) {
      _showSnackbar('No feedback available for this provider.', isError: true);
      return;
    }

    final feedbackList = (feedbackData as Map<dynamic, dynamic>)
        .entries
        .map((entry) => Map<String, dynamic>.from(entry.value as Map))
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Provider Feedback'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: feedbackList.map((feedback) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      feedback['fullName'] ?? 'Anonymous',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feedback['feedback'] ?? 'No feedback'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Rating:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Text(feedback['rating']?.toString() ?? 'N/A'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feedback['timestamp'] ?? '',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Helper method to build an info tile
  Widget _buildInfoTile(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.info,
          color: Colors.blueAccent,
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(value ?? 'N/A'),
      ),
    );
  }

  /// Helper method to display a snackbar
  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.selectedJob;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.providerName} - Job Details'),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['jobTitle'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const Divider(),
                _buildDetailRow('Provider:', widget.providerName),
                _buildDetailRow('Experience:', job['experience'] ?? 'N/A'),
                _buildDetailRow('Expertise:', job['expertise'] ?? 'N/A'),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isBooked ? _cancelBooking : _pickDateAndBookJob,
                    icon: Icon(
                      _isBooked ? Icons.cancel : Icons.calendar_today,
                    ),
                    label: Text(_isBooked ? 'Cancel Booking' : 'Book Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBooked ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _viewProviderProfile,
                    icon: const Icon(Icons.person),
                    label: const Text('View Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _reportUser,
                    icon: const Icon(Icons.flag),
                    label: const Text('Report User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
