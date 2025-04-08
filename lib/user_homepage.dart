import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'provider_job.dart'; // Import ProviderJobsPage
import 'booked_page.dart'; // Import BookedPage
import 'profile_page.dart'; // Import ProfilePage
import 'chatpage.dart'; // Import ChatPages
import 'login.dart'; // Import LoginPage

class UserHomePage extends StatefulWidget {
  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('userprofiles');

  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;
  Map<String, dynamic> _currentUserProfile = {};
  String _searchQuery = '';
  String? _selectedCategory;

  int _currentIndex = 0;

  final List<String> _categories = [
    "AC Cleaning",
    "House Cleaning",
    "Keymaker",
    "Installation Appliances",
    "Plumbing",
    "Landscaping",
    "Massage",
  ];

  @override
  void initState() {
    super.initState();
    _fetchJobsOfferedByProviders();
    _fetchCurrentUserProfile();
    _fetchProviders();
  }

  Future<void> _fetchJobsOfferedByProviders() async {
    try {
      final snapshot = await _dbRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> tempJobs = [];

        data.forEach((key, value) {
          final provider = Map<String, dynamic>.from(value);
          if (provider['userType'] == 'Provider' &&
              provider.containsKey('jobs')) {
            final jobs = provider['jobs'] as Map<dynamic, dynamic>;
            jobs.forEach((jobKey, jobValue) {
              final job = Map<String, dynamic>.from(jobValue);

              if (job['activate'] == true) {
                double? firstRating;
                List<Map<String, dynamic>> feedbacks = [];

                if (provider.containsKey('feedbacks')) {
                  final feedbackData =
                      provider['feedbacks'] as Map<dynamic, dynamic>;
                  feedbacks = feedbackData.entries.map((entry) {
                    final feedback = Map<String, dynamic>.from(entry.value);
                    return {
                      'feedback': feedback['feedback'] ?? '',
                      'fullName': feedback['fullName'] ?? 'Anonymous',
                      'rating': feedback['rating'] ?? 0,
                      'timestamp': feedback['timestamp'] ?? '',
                    };
                  }).toList();

                  if (feedbacks.isNotEmpty) {
                    firstRating = feedbacks.first['rating']?.toDouble();
                  }
                }

                tempJobs.add({
                  'providerId': key,
                  'providerName':
                      '${provider['firstName'] ?? 'N/A'} ${provider['lastName'] ?? 'N/A'}',
                  'jobTitle': job['jobTitle'] ?? 'No Title',
                  'category': job['category'] ?? 'No Category',
                  'experience': job['experience'] ?? 'N/A',
                  'expertise': job['expertise'] ?? 'N/A',
                  'description': job['about'] ?? 'No Description',
                  'activate': job['activate'] ?? false,
                  'firstRating': firstRating,
                  'feedbacks': feedbacks,
                });
              }
            });
          }
        });

        setState(() {
          _jobs = tempJobs;
          _filteredJobs = tempJobs;
          _isLoading = false;
        });
      } else {
        debugPrint('No data found in the userprofiles node.');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProviders() async {
    try {
      final snapshot = await _dbRef.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> tempProviders = [];

        data.forEach((key, value) {
          final provider = Map<String, dynamic>.from(value);
          if (provider['userType'] == 'Provider') {
            tempProviders.add({
              'id': key,
              'firstName': provider['firstName'] ?? 'N/A',
              'lastName': provider['lastName'] ?? 'N/A',
              'email': provider['email'] ?? 'N/A',
            });
          }
        });

        setState(() {
          _providers = tempProviders;
        });
      }
    } catch (e) {
      print('Error fetching providers: $e');
    }
  }

  Future<void> _fetchCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final snapshot = await _dbRef.child(user.uid).get();
        if (snapshot.exists) {
          setState(() {
            _currentUserProfile =
                Map<String, dynamic>.from(snapshot.value as Map);
          });
        }
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  void _filterJobs(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredJobs = _jobs.where((job) {
        final jobTitle = job['jobTitle'].toLowerCase();
        final expertise = job['expertise'].toLowerCase();
        final category = job['category'].toLowerCase();
        final providerName = job['providerName'].toLowerCase();

        return (jobTitle.contains(_searchQuery) ||
                expertise.contains(_searchQuery) ||
                category.contains(_searchQuery) ||
                providerName.contains(_searchQuery)) &&
            (_selectedCategory == null ||
                job['category'].toLowerCase() ==
                    _selectedCategory!.toLowerCase());
      }).toList();
    });
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _filterJobs(_searchQuery);
    });
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                _filterByCategory(selected ? category : null);
              },
              selectedColor: Colors.blueAccent,
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search Jobs',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _filterJobs,
          ),
        ),
        _buildCategoryFilter(),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredJobs.isEmpty
                    ? const Center(
                        child: Text(
                          'No jobs found.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filteredJobs.length,
                        itemBuilder: (context, index) {
                          final job = _filteredJobs[index];
                          final firstRating = job['firstRating'] as double?;
                          final feedbacks =
                              job['feedbacks'] as List<Map<String, dynamic>>? ??
                                  [];

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job['jobTitle'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Category: ${job['category']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Experience: ${job['experience']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Expertise: ${job['expertise']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Provider: ${job['providerName']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ProviderJobsPage(
                                            providerId: job['providerId'],
                                            providerName: job['providerName'],
                                            selectedJob: job,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Request Service'),
                                  ),
                                  const SizedBox(height: 8),
                                  if (firstRating !=
                                      null) // Only display if rating exists
                                    GestureDetector(
                                      onTap: () =>
                                          _showFeedbackList(context, feedbacks),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          '$firstRating ⭐',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
      ],
    );
  }

  Widget _buildBookedJobsPage() {
    return BookedPage(userId: _auth.currentUser?.uid ?? '');
  }

  void _showFeedbackList(
      BuildContext context, List<Map<String, dynamic>> feedbacks) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Feedback',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const Divider(),
              feedbacks.isEmpty
                  ? const Center(
                      child: Text(
                        'No feedback available.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: feedbacks.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbacks[index];
                        return ListTile(
                          title: Text(
                            feedback['feedback'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            'By: ${feedback['fullName'] ?? 'Anonymous'}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Text(
                            '${feedback['rating'] ?? 0} ⭐',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  void _showProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ProfilePage(
          userProfile: _currentUserProfile,
          onLogout: () {
            Navigator.pop(context);
            _logout(context);
          },
        );
      },
    );
  }

  void _showChatProviderSelector() {
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
              const Text(
                'Select Provider to Chat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const Divider(),
              Expanded(
                child: _providers.isEmpty
                    ? const Center(
                        child: Text(
                          'No providers available for chat.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _providers.length,
                        itemBuilder: (context, index) {
                          final provider = _providers[index];
                          return ListTile(
                            leading: const Icon(Icons.person,
                                color: Colors.blueAccent),
                            title: Text(
                                '${provider['firstName']} ${provider['lastName']}'),
                            subtitle: Text(provider['email']),
                            onTap: () {
                              Navigator.pop(context);
                              _startChatWithProvider(provider);
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

  void _startChatWithProvider(Map<String, dynamic> provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPages(
          currentUserId: _auth.currentUser?.uid ?? '',
          receiverId: provider['id'],
          receiverName: '${provider['firstName']} ${provider['lastName']}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            tooltip: 'View Profile',
            onPressed: _showProfileModal,
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildJobsPage() : _buildBookedJobsPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Booked Jobs',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showChatProviderSelector,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.chat, color: Colors.white),
        tooltip: 'Chat with a Provider',
      ),
    );
  }
}
