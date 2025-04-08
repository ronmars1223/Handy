import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AddJobPage extends StatefulWidget {
  @override
  _AddJobPageState createState() => _AddJobPageState();
}

class _AddJobPageState extends State<AddJobPage> {
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _expertiseController = TextEditingController();

  final DatabaseReference _userProfilesRef =
      FirebaseDatabase.instance.ref('userprofiles'); // Userprofiles Node
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedCategory; // Holds the selected category
  bool _isLoading = false;

  final List<String> _categories = [
    'AC Cleaning',
    'House Cleaning',
    'Keymaker',
    'Installation Appliances',
    'Plumbing',
    'Landscaping',
    'Massage',
  ];

  Future<void> _addJob() async {
    if (_jobTitleController.text.isEmpty ||
        _experienceController.text.isEmpty ||
        _aboutController.text.isEmpty ||
        _expertiseController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and select a category')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // Reference to the provider's jobs inside userprofiles
      final DatabaseReference jobsRef =
          _userProfilesRef.child('${user.uid}/jobs');

      // Fetch current jobs to determine the next sequential key
      final snapshot = await jobsRef.get();
      int nextJobNumber = 1;

      if (snapshot.exists) {
        // Count existing jobs
        nextJobNumber = snapshot.children.length + 1;
      }

      // Check if subscription exists
      final userProfileSnapshot = await _userProfilesRef.child(user.uid).get();
      bool isSubscriptionActive = false;

      if (userProfileSnapshot.exists) {
        final userProfileData = userProfileSnapshot.value as Map;
        if (userProfileData.containsKey('subscription') &&
            userProfileData['subscription'] != null &&
            userProfileData['subscription'].toString().isNotEmpty) {
          isSubscriptionActive = true;
        }
      }

      // Add job with a sequential key
      await jobsRef.child('job $nextJobNumber').set({
        'jobTitle': _jobTitleController.text.trim(),
        'experience': _experienceController.text.trim(),
        'about': _aboutController.text.trim(),
        'expertise': _expertiseController.text.trim(),
        'category': _selectedCategory, // Add selected category
        'activate': isSubscriptionActive, // Set activate status
        'timestamp': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Job added successfully! ${isSubscriptionActive ? "Activated" : "Pending Activation"}'),
        ),
      );

      // If you still need to navigate back, ensure AddJobPage was opened as a modal.
      // Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding job: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(
            child: Text(
              'Create a Job Post',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _jobTitleController,
            label: 'Job Title',
            icon: Icons.work_outline,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _experienceController,
            label: 'Experience (e.g., 2 years)',
            icon: Icons.timeline,
          ),
          const SizedBox(height: 16),
          _buildCategoryDropdown(), // Category selection dropdown
          const SizedBox(height: 16),
          _buildTextField(
            controller: _aboutController,
            label: 'Tell About Yourself',
            icon: Icons.person_outline,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _expertiseController,
            label: 'Expertise (e.g., Carpentry)',
            icon: Icons.build,
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _addJob,
              icon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(
                _isLoading ? 'Saving...' : 'Submit Job',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Select Category',
        prefixIcon: const Icon(Icons.category, color: Colors.blueAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
    );
  }
}
