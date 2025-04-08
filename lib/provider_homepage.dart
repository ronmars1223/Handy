import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:handycrew/chatpage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'add_job.dart';
import 'booking_page.dart';
import 'profile_page.dart';
import 'login.dart';

class ProviderHomePage extends StatefulWidget {
  @override
  _ProviderHomePageState createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends State<ProviderHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  File? _receiptImage;
  final ImagePicker _picker = ImagePicker();

  String _gcashNumber = "Loading...";
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _users = []; // List to store chat users
  bool _isLoadingJobs = true;
  Map<String, dynamic> _providerProfile = {};

  int _currentIndex = 0; // Bottom navigation bar index

  @override
  void initState() {
    super.initState();
    _fetchGCashNumber();
    _fetchProviderJobs();
    _fetchProviderProfile();
  }

  /// Fetch GCash Number
  Future<void> _fetchGCashNumber() async {
    try {
      final snapshot = await _dbRef.child('gcash-number/number').get();
      if (snapshot.exists) {
        setState(() {
          _gcashNumber = snapshot.value.toString();
        });
      } else {
        setState(() {
          _gcashNumber = "Not Available";
        });
      }
    } catch (e) {
      setState(() {
        _gcashNumber = "Error fetching GCash number";
      });
      print("Error fetching GCash number: $e");
    }
  }

  /// Fetch Provider Profile
  Future<void> _fetchProviderProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _dbRef.child('userprofiles/${user.uid}').get();
        if (snapshot.exists) {
          setState(() {
            _providerProfile = Map<String, dynamic>.from(snapshot.value as Map);
          });
        }
      }
    } catch (e) {
      print('Error fetching provider profile: $e');
    }
  }

  Future<void> _fetchProviderJobs() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DatabaseReference jobsRef = _dbRef.child('userprofiles/${user.uid}/jobs');

      jobsRef.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          setState(() {
            _jobs = data.entries.map((entry) {
              final value = Map<String, dynamic>.from(entry.value);
              return {
                'key': entry.key, // Store the job key
                'title': value['jobTitle'] ?? 'No Title',
                'experience': value['experience'] ?? 'No Experience',
                'expertise': value['expertise'] ?? 'No Expertise',
                'category': value['category'] ?? '',
                'activate': value['activate'] ?? false,
              };
            }).toList();
          });
        } else {
          setState(() {
            _jobs = [];
          });
        }

        setState(() {
          _isLoadingJobs = false;
        });
      });
    } catch (e) {
      print("Error fetching jobs: $e");
      setState(() {
        _isLoadingJobs = false;
      });
    }
  }

  /// Fetch Users for Chat
  Future<void> _fetchUsers() async {
    try {
      final snapshot = await _dbRef.child('userprofiles').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> tempUsers = [];

        data.forEach((key, value) {
          final user = Map<String, dynamic>.from(value);
          if (user['userType'] == 'User') {
            tempUsers.add({
              'id': key,
              'firstName': user['firstName'] ?? 'N/A',
              'lastName': user['lastName'] ?? 'N/A',
              'email': user['email'] ?? '',
            });
          }
        });

        setState(() {
          _users = tempUsers; // Store users in the _users list
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  /// Show Chat Users Modal
  void _showChatUsersModal() async {
    await _fetchUsers();
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: Text(
                  'Select User to Chat',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent),
                ),
              ),
              const Divider(),
              Expanded(
                child: _users.isEmpty
                    ? Center(
                        child: Text(
                          'No users available.',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return ListTile(
                            leading:
                                const Icon(Icons.person, color: Colors.blue),
                            title: Text(
                                '${user['firstName']} ${user['lastName']}'),
                            subtitle: Text(user['email']),
                            onTap: () {
                              Navigator.pop(context);
                              _startChatWithUser(user);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startChatWithUser(Map<String, dynamic> user) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPages(
            currentUserId: currentUserId, // Actual logged-in user's ID
            receiverId: user['id'], // The recipient's ID
            receiverName:
                '${user['firstName']} ${user['lastName']}', // Recipient's full name
          ),
        ),
      );
    } else {
      // Handle the case where the user is not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build Main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text(
          'Provider Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showProfileModal,
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _buildSelectedScreen(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showChatUsersModal,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.chat, color: Colors.white),
        tooltip: 'Chat with a User',
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor:
            Colors.blueAccent, // Text color for the selected item
        unselectedItemColor:
            Colors.blue[200], // Text color for unselected items
        type: BottomNavigationBarType.fixed, // Ensures all items are shown
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Add Job',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.subscriptions),
            label: 'Subscriptions',
          ),
        ],
      ),
    );
  }

  /// Select screen based on index
  Widget _buildSelectedScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreen(); // Home Page
      case 1:
        return AddJobPage(); // Add Job Page
      case 2:
        return const BookedUsersPage(); // Bookings Page
      case 3:
        return _buildSubscriptionsScreen(); // Subscriptions
      default:
        return Container();
    }
  }

  Widget _buildHomeScreen() {
    return _isLoadingJobs
        ? const Center(child: CircularProgressIndicator())
        : _jobs.isEmpty
            ? const Center(
                child: Text(
                  'No jobs available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Job Details (Left Side)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job['title'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Experience: ${job['experience']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Expertise: ${job['expertise']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit and Delete Buttons (Right Side)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.orange),
                                onPressed: () {
                                  _showEditJobDialog(job, index);
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteConfirmationDialog(job, index);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }

  void _showEditJobDialog(Map<String, dynamic> job, int index) {
    final TextEditingController jobTitleController =
        TextEditingController(text: job['title'] ?? '');
    final TextEditingController experienceController =
        TextEditingController(text: job['experience'] ?? '');
    final TextEditingController expertiseController =
        TextEditingController(text: job['expertise'] ?? '');

    // Category List
    final List<String> categories = [
      'AC Cleaning',
      'House Cleaning',
      'Keymaker',
      'Installation Appliances',
      'Plumbing',
      'Landscaping',
      'Massage',
    ];

    // Selected category state
    String? selectedCategory = job['category'] ?? categories.first;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Job'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: jobTitleController,
                  decoration: const InputDecoration(labelText: 'Job Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: experienceController,
                  decoration: const InputDecoration(labelText: 'Experience'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: expertiseController,
                  decoration: const InputDecoration(labelText: 'Expertise'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedCategory = value ?? categories.first;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () async {
                await _updateJob(
                  index: index,
                  title: jobTitleController.text.isEmpty
                      ? 'Untitled Job'
                      : jobTitleController.text,
                  experience: experienceController.text.isEmpty
                      ? 'No experience provided'
                      : experienceController.text,
                  expertise: expertiseController.text.isEmpty
                      ? 'No expertise provided'
                      : expertiseController.text,
                  category: selectedCategory ?? categories.first,
                );
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateJob({
    required int index,
    required String title,
    required String experience,
    required String expertise,
    required String category,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      final String jobKey = _jobs[index]['key'];

      final DatabaseReference jobRef =
          _dbRef.child('userprofiles/${user.uid}/jobs').child(jobKey);

      await jobRef.update({
        'jobTitle': title,
        'experience': experience,
        'expertise': expertise,
        'category': category,
      });

      setState(() {
        _jobs[index] = {
          'key': jobKey,
          'title': title,
          'experience': experience,
          'expertise': expertise,
          'category': category,
          'activate': _jobs[index]['activate'],
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job "$title" updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show a confirmation dialog before deleting a job
  void _showDeleteConfirmationDialog(Map<String, dynamic> job, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Job'),
          content: Text(
              'Are you sure you want to delete the job titled "${job['title']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                _deleteJob(job, index); // Call the updated delete method
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// Delete a job from the database and UI
  Future<void> _deleteJob(Map<String, dynamic> job, int index) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in.');
      }

      // Reference to the specific job in the database
      DatabaseReference jobRef =
          _dbRef.child('userprofiles/${user.uid}/jobs').child(job['key']);

      // Remove the job from the database
      await jobRef.remove();

      // Remove the job from the local list
      setState(() {
        _jobs.removeAt(index);
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job "${job['title']}" deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Handle errors and show a failure message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Subscriptions Screen
  Widget _buildSubscriptionsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Subscription Plans',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () {
              _showSubscriptionDialog(context);
            },
            child: const Text('View Subscription Options'),
          ),
        ],
      ),
    );
  }

  /// Show Profile Modal
  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ProfilePage(
          userProfile: _providerProfile,
          onLogout: () {
            Navigator.pop(context); // Close modal
            _logout(context); // Perform logout
          },
        );
      },
    );
  }

  /// Logout
  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  /// Show Subscription Dialog
  void _showSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose Subscription Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.calendar_month, color: Colors.blueAccent),
                title: const Text('Monthly Subscription'),
                subtitle: const Text('₱99 per month'),
                onTap: () {
                  Navigator.pop(context); // Close subscription dialog
                  _showGCashPaymentDialog(context, 'Monthly', 99);
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.calendar_today, color: Colors.greenAccent),
                title: const Text('Yearly Subscription'),
                subtitle: const Text('₱1000 per year'),
                onTap: () {
                  Navigator.pop(context); // Close subscription dialog
                  _showGCashPaymentDialog(context, 'Yearly', 1000);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  /// GCash Payment Dialog
  void _showGCashPaymentDialog(BuildContext context, String plan, int amount) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Payment Instructions'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Please pay ₱$amount for the $plan plan using the GCash number below:',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_android, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        _gcashNumber,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        setState(() {
                          _receiptImage = File(pickedFile.path);
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: _receiptImage == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload,
                                      size: 40, color: Colors.grey[600]),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Receipt',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : Image.file(
                              _receiptImage!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.blue)),
                ),
                TextButton(
                  onPressed: () async {
                    if (_receiptImage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Uploading receipt...'),
                        ),
                      );

                      try {
                        String uid = FirebaseAuth.instance.currentUser!.uid;
                        String fileName =
                            '$uid-${DateTime.now().millisecondsSinceEpoch}';
                        Reference storageRef = FirebaseStorage.instance
                            .ref()
                            .child('Gcash-receipts/$uid/$fileName');

                        UploadTask uploadTask =
                            storageRef.putFile(_receiptImage!);
                        TaskSnapshot snapshot = await uploadTask;

                        String downloadUrl =
                            await snapshot.ref.getDownloadURL();

                        DatabaseReference receiptRef = FirebaseDatabase.instance
                            .ref('Gcash-receipts')
                            .child(uid);

                        await receiptRef.set({
                          'amount': amount,
                          'subscriptionPlan': plan,
                          'receiptUrl': downloadUrl,
                          'timestamp': DateTime.now().toIso8601String(),
                          'uid': uid,
                          'email': FirebaseAuth.instance.currentUser?.email,
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Receipt uploaded successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        Navigator.pop(dialogContext);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error uploading receipt: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please upload a receipt first.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: const Text('Submit',
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
