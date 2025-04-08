import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class EditProfilePage extends StatefulWidget {
  final User? user;

  EditProfilePage({this.user});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const double MinLatitude = 7.15;
  static const double MaxLatitude = 7.45;
  static const double MinLongitude = 125.45;
  static const double MaxLongitude = 125.75;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _selectedUserType = 'User';
  final List<String> _userTypes = ['Provider', 'User'];
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  double? _latitude;
  double? _longitude;
  bool _isLocationFetched = false; // Track location fetch status

  Future<void> _saveProfile() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all the fields')),
      );
      return;
    }

    try {
      await _database.child('userprofiles/${widget.user?.uid}').set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'userType': _selectedUserType,
        'coordinates': {
          'latitude': _latitude ?? 'Not provided',
          'longitude': _longitude ?? 'Not provided',
        },
        'email': widget.user?.email,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile Updated Successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (position.latitude >= MinLatitude &&
          position.latitude <= MaxLatitude &&
          position.longitude >= MinLongitude &&
          position.longitude <= MaxLongitude) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isLocationFetched = true; // Mark location as fetched
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location fetched: Latitude: $_latitude, Longitude: $_longitude'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location is outside Panabo City boundaries'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInputField(
                          controller: _firstNameController,
                          label: 'First Name',
                          icon: Icons.person,
                        ),
                        SizedBox(height: 16),
                        _buildInputField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          icon: Icons.person_outline,
                        ),
                        SizedBox(height: 16),
                        _buildInputField(
                          controller: _contactController,
                          label: 'Contact Number',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 16),
                        _buildInputField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.home,
                        ),
                        SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedUserType,
                          items: _userTypes
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUserType = value!;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'User Type',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: Icon(Icons.location_on),
                          label: Text('Get Current Location'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if (_latitude != null && _longitude != null) ...[
                          SizedBox(height: 16),
                          Text(
                            'Latitude: $_latitude\nLongitude: $_longitude',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: _isLocationFetched ? _saveProfile : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 56),
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save Profile',
                      style: TextStyle(fontSize: 18, color: Colors.white),
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
}
