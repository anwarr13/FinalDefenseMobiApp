import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'login_screen.dart';

class MoodCategoryScreen extends StatefulWidget {
  const MoodCategoryScreen({Key? key}) : super(key: key);

  @override
  State<MoodCategoryScreen> createState() => _MoodCategoryScreenState();
}

class _MoodCategoryScreenState extends State<MoodCategoryScreen> {
  final Set<String> selectedFeatures = {};
  bool _isLoading = false;
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile not found. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        _redirectToLogin();
        return;
      }

      final userData = userDoc.data();
      final String? userRole = userData?['role']?.toString().toLowerCase();

      if (userRole != 'user') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Access denied. This area is for regular users only.'),
            backgroundColor: Colors.red,
          ),
        );
        _redirectToLogin();
        return;
      }

      setState(() => _isCheckingRole = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error checking user role. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        _redirectToLogin();
      }
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Categories of bar features
  final List<Map<String, dynamic>> categories = [
    {
      'title': 'Vibe & Atmosphere',
      'features': [
        'Live Music',
        'Sports Events',
        'Pool Tables',
        'Bar Games',
        'Live Band',
        'Wine Bar',
        'Beach View',
        'Modern',
        'Rooftop View',
        'VIP Rooms',
        'Karaoke Bar',
        'Outdoor Setting',
        'Garden Setting',
        'Restrooms',
        'Parking Spaces'
      ]
    },
  ];

  Future<void> _savePreferencesAndNavigate() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('userPreferences', selectedFeatures.toList());

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'preferences': selectedFeatures.toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              selectedFeatures: selectedFeatures.toList(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving preferences. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
        backgroundColor: const Color.fromARGB(221, 254, 254, 254),
        actions: [
          if (selectedFeatures.isNotEmpty)
            TextButton(
              onPressed: _savePreferencesAndNavigate,
              child: Text(
                'Done (${selectedFeatures.length})',
                style: const TextStyle(color: Color.fromARGB(255, 7, 2, 2)),
              ),
            ),
        ],
      ),
      body: _isCheckingRole
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select features that match your mood:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We\'ll show you bars that match your preferences',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 6),
                        ...categories
                            .map((category) => _buildCategorySection(category)),
                        const SizedBox(height: 80), // Space for bottom button
                      ],
                    ),
                  ),
                ),
      floatingActionButton: selectedFeatures.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _savePreferencesAndNavigate,
              backgroundColor: const Color.fromARGB(221, 251, 251, 252),
              icon: const Icon(Icons.map),
              label: Text('Show ${selectedFeatures.length} matches'),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                );
              },
              backgroundColor: const Color.fromARGB(221, 251, 251, 252),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Show All Bars'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            category['title'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: (category['features'] as List).map((feature) {
            bool isSelected = selectedFeatures.contains(feature);
            return FilterChip(
              label: Text(feature),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedFeatures.add(feature);
                  } else {
                    selectedFeatures.remove(feature);
                  }
                });
              },
              selectedColor: Colors.black87.withOpacity(0.2),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
            );
          }).toList(),
        ),
        //   const Divider(height: 32),
      ],
    );
  }
}
