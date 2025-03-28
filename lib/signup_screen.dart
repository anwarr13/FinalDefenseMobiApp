import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login_form/set_operations_hours_screen.dart';
import 'location_picker_screen.dart';
import 'package:philippines_rpcmb/philippines_rpcmb.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _retypePasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _barNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _streetAddressController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _permitNumberController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isRetypePasswordVisible = false;
  String? _selectedGender;

  // List of Genders available when filling up the form
  final List<String> _genders = [
    'Male',
    'Female',
    'LGBTQIA+',
    'Prefer not to say'
  ];
  String _selectedUserType = 'User';
  bool _isLoading = false;
  // DateTime? _selectedBirthday;
  bool _showRoleSelection = true;
  bool _isBarOwner = false;
  LatLng? _selectedLocation;

  // Philippines RCPMB Package
  Region? region;
  Province? province;
  Municipality? municipality;
  String? barangay;

  // Mood Category Options
  final Set<String> _selectedFeatures = <String>{};
  final List<String> _availableFeatures = [
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
  ];

  DateTime? _selectedBirthdate;
  final DateTime _minDate =
      DateTime.now().subtract(const Duration(days: 365 * 90)); // 90 years ago
  final DateTime _maxDate =
      DateTime.now().subtract(const Duration(days: 365 * 18)); // 18 years ago

  Map<String, OperatingHours>? _selectedOperatingHours;

  String? _permitImagePath;
  String? _permitImageUrl;

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedBirthdate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your birth date.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      //  Validate permit number for bar owners
      // if (_isBarOwner && _permitNumberController.text.isEmpty) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('Please enter your business permit number.'),
      //       backgroundColor: Colors.red,
      //     ),
      //   );
      //   return;
      // }

      if (_isBarOwner && _permitImageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please wait for the permit photo to finish uploading.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_isBarOwner && _selectedOperatingHours == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your bar\'s operating hours'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final age = _calculateAge(_selectedBirthdate!);
      if (age < 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be at least 18 years old to register.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (age > 90) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid birth date.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Create the user account
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Prepare location data if available
        GeoPoint? locationGeoPoint;
        if (_selectedLocation != null) {
          locationGeoPoint = GeoPoint(
              _selectedLocation!.latitude, _selectedLocation!.longitude);
        }

        // Create base user document
        final userData = {
          'email': _emailController.text,
          'firstName': _firstNameController.text,
          'middleName': _middleNameController.text,
          'lastName': _lastNameController.text,
          'gender': _selectedGender,
          'role': _isBarOwner ? 'bar_owner' : 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'province': province?.name,
          'municipality': municipality?.name,
          'barangay': barangay,
          'streetAddress': _streetAddressController.text,
          'status':
              _isBarOwner ? 'pending' : 'active', // Bar owners start as pending
          'approved': !_isBarOwner, // Regular users are auto-approved
          'birthdate': _selectedBirthdate,
          'contactNumber': _contactNumberController.text,
        };

        if (_isBarOwner) {
          // Add bar-specific data
          final barData = {
            ...userData,
            'barName': _barNameController.text,
            'operatingHours': _selectedOperatingHours?.map(
              (key, value) => MapEntry(key, value.toJson()),
            ),
            'features': _selectedFeatures.toList(),
            'permitNumber': _permitNumberController.text,
            'permitImagePath': _permitImageUrl,
            'location': locationGeoPoint,
            'address': {
              'street': _streetAddressController.text,
              'barangay': barangay,
              'municipality': municipality?.name,
              'province': province?.name,
              'region': region?.regionName,
            },
            'description': _descriptionController.text,
            'registrationDate': FieldValue.serverTimestamp(),
            'status': 'pending',
          };

          // Save to users collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(userData);

          // Save to pending_bars collection for admin approval
          await FirebaseFirestore.instance
              .collection('pending_bars')
              .doc(userCredential.user!.uid)
              .set(barData);
        } else {
          // Save regular user to users collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(userData);
        }

        if (!mounted) return;

        // Clear the form
        //_clearFields();

        // Show success dialog with appropriate message
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
                _isBarOwner ? 'Registration Pending' : 'Sign Up Successful'),
            content: Text(_isBarOwner
                ? 'Your bar registration has been submitted for approval. You will be notified once an admin reviews your application.'
                : 'Your account has been created successfully!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        _passwordController.clear();
        _retypePasswordController.clear();

        if (!mounted) return;

        // Show error dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(_getErrorMessage(e.code)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        setState(() => _isLoading = false);
        _passwordController.clear();
        _retypePasswordController.clear();

        if (!mounted) return;

        // Show error dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content:
                const Text('An unexpected error occured. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Function to get user-friendly error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'Please enter a stronger password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'An error occured please try again.';
    }
  }

  void _navigateToRegistration(String userType) {
    // Clear all fields first
    //_clearFields();

    setState(() {
      _showRoleSelection = false;
      _isBarOwner = userType == 'Bar Owner';
      _selectedUserType = userType;

      // Reset password visibility states
      _isPasswordVisible = false;
      _isRetypePasswordVisible = false;
    });
  }

  // Back button handler in AppBar
  void _handleBack() {
    if (!_showRoleSelection) {
      // If we're in registration form, go back to role selection
      //_clearFields();
      setState(() {
        _showRoleSelection = true;
        _isBarOwner = false;
        _selectedUserType = 'User';
      });
    } else {
      // If we're in role selection, exit the screen
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: _handleBack,
          ),
          title: Text(
            _showRoleSelection
                ? 'Choose Account Type'
                : _isBarOwner
                    ? 'Bar Owner Registration'
                    : 'User Registration',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          child: _showRoleSelection
              ? _buildRoleSelection()
              : _buildRegistrationForm(),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your account type to get started',
            style: TextStyle(
              fontSize: 20,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _buildAccountTypeCard(
                  title: 'Customer',
                  icon: Icons.person_outline,
                  description: 'Discover and explore bars in your area',
                  color: Colors.blue.shade50,
                  iconColor: Colors.blue,
                  onTap: () => _navigateToRegistration('User'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAccountTypeCard(
                  title: 'Bar Owner',
                  icon: Icons.business,
                  description: 'Manage and promote your bar',
                  color: Colors.orange.shade50,
                  iconColor: Colors.orange,
                  onTap: () => _navigateToRegistration('Bar Owner'),
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header section with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      _isBarOwner
                          ? 'Bar Owner Registration'
                          : 'User Registration',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_isBarOwner) ...[
                      Text(
                        'Step ${_currentStep + 1} of ${_stepTitles.length}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stepTitles[_currentStep],
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else
                      Text(
                        'Create your account to discover amazing bars near you',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Form content
              if (_isBarOwner)
                SizedBox(
                  height: 600, // Adjust height as needed
                  child: PageView(
                    controller: _pageController,
                    physics: NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                    },
                    children: [
                      // Step 1: Personal and Account Information
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            _buildPersonalInfoSection(),
                            const SizedBox(height: 32),
                            _buildAccountInfoSection(),
                          ],
                        ),
                      ),
                      // Step 2: Bar Details
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            _buildBarInfoSection(),
                            const SizedBox(height: 32),
                            _buildBarFeaturesSection(),
                            const SizedBox(height: 32),
                            _buildLocationSection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 32),
                    _buildAccountInfoSection(),
                    const SizedBox(height: 32),
                  ],
                ),

              const SizedBox(height: 24),

              // Navigation buttons
              if (_isBarOwner)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      TextButton.icon(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep < _stepTitles.length - 1) {
                                if (_validateStep1()) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              } else {
                                if (_validateStep2()) {
                                  _signUp();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 11),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColorLight,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('Processing...'),
                              ],
                            )
                          : Text(
                              _currentStep == _stepTitles.length - 1
                                  ? 'Submit Registration'
                                  : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 11),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColorLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Processing...'),
                          ],
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

              // const SizedBox(height: 16),
              // TextButton.icon(
              //   onPressed: () {
              //     setState(() {
              //       _showRoleSelection = true;
              //       _isBarOwner = false;
              //       _clearFields();
              //     });
              //   },
              //   icon: const Icon(Icons.arrow_back),
              //   label: const Text('Back to Role Selection'),
              //   style: TextButton.styleFrom(
              //     foregroundColor: Colors.grey[700],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validateStep1() {
    final formState = _formKey.currentState;
    if (formState == null) return false;

    bool isValid = true;
    String? errorMessage;

    // Validate Personal Information
    if (_selectedBirthdate == null) {
      errorMessage = 'Please select your birth date';
      isValid = false;
    } else if (_selectedGender == null) {
      errorMessage = 'Please select your gender';
      isValid = false;
    }

    // Validate Account Information
    if (_emailController.text.isEmpty) {
      errorMessage = 'Email is required';
      isValid = false;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(_emailController.text)) {
      errorMessage = 'Please enter a valid email address';
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      errorMessage = 'Password is required';
      isValid = false;
    } else if (_passwordController.text.length < 6) {
      errorMessage = 'Password must be at least 6 characters';
      isValid = false;
    }

    if (_passwordController.text != _retypePasswordController.text) {
      errorMessage = 'Passwords do not match';
      isValid = false;
    }

    if (!isValid && errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return formState.validate();
  }

  bool _validateStep2() {
    final formState = _formKey.currentState;
    if (formState == null) return false;

    bool isValid = true;
    String? errorMessage;

    // Validate Bar Information
    if (_barNameController.text.isEmpty) {
      errorMessage = 'Bar name is required';
      isValid = false;
    }

    // Validate Bar Features
    if (_selectedFeatures.isEmpty) {
      errorMessage = 'Please select at least one feature';
      isValid = false;
    }

    // Validate Location
    if (_selectedLocation == null) {
      errorMessage = 'Please select your bar location';
      isValid = false;
    }

    if (!isValid && errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return formState.validate();
  }

  final List<String> _stepTitles = [
    'Account Information',
    'Your Bar Details',
  ];

  late PageController _pageController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  Widget _buildSectionContainer({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdateField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _selectDate(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedBirthdate != null
                      ? '${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year}'
                      : 'Select Birth Date',
                  style: TextStyle(
                    color: _selectedBirthdate != null
                        ? Colors.black87
                        : Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? _maxDate,
      firstDate: _minDate,
      lastDate: _maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final age = _calculateAge(picked);
      if (age < 18) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be at least 18 years old to register.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (age > 90) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid birth date.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  Future<void> _uploadPermitImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final storageRef = FirebaseStorage.instance.ref();
      final permitRef = storageRef.child(
          'permits/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');

      // Upload the file
      final uploadTask = permitRef.putFile(file);

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        // You could show a progress indicator here if needed
      });

      // Get the download URL when upload completes
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _permitImageUrl = downloadUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload permit image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      // Clear the local path if upload fails
      setState(() {
        _permitImagePath = null;
      });
    }
  }

  Widget _buildPersonalInfoSection() {
    return _buildSectionContainer(
      title: 'Personal Information',
      children: [
        TextFormField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: 'First Name',
            hintText: 'Enter your first name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'First name is required';
            }
            if (value.length < 2) {
              return 'First name must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _middleNameController,
          decoration: InputDecoration(
            labelText: 'Middle Name (Optional)',
            hintText: 'Enter your middle name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: 'Last Name',
            hintText: 'Enter your last name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Last name is required';
            }
            if (value.length < 2) {
              return 'Last name must be at least 2 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildBirthdateField(),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: InputDecoration(
            labelText: 'Gender',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _genders.map((String gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select your gender';
            }
            return null;
          },
        ),
      ],
      icon: Icons.person_outline,
    );
  }

  Widget _buildAccountInfoSection() {
    return _buildSectionContainer(
      title: 'Account Information',
      children: [
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email address',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email address is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            helperText:
                'Password must contain at least 6 characters, one uppercase letter, one number, and one special character',
            helperMaxLines: 2,
          ),
          obscureText: !_isPasswordVisible,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            if (!RegExp(r'[A-Z]').hasMatch(value)) {
              return 'Password must contain at least one uppercase letter';
            }
            if (!RegExp(r'[0-9]').hasMatch(value)) {
              return 'Password must contain at least one number';
            }
            if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
              return 'Password must contain at least one special character';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _retypePasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isRetypePasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isRetypePasswordVisible = !_isRetypePasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          obscureText: !_isRetypePasswordVisible,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
      icon: Icons.lock_outline,
    );
  }

  Widget _buildBarInfoSection() {
    return _buildSectionContainer(
      title: 'Bar Information',
      icon: Icons.local_bar,
      children: [
        TextFormField(
          controller: _barNameController,
          decoration: const InputDecoration(
            labelText: 'Bar Name',
            prefixIcon: Icon(Icons.storefront),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your bar name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description for your bar';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final ImagePicker picker = ImagePicker();
            final XFile? image = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1920,
              maxHeight: 1080,
              imageQuality: 85,
            );
            if (image != null) {
              setState(() {
                _permitImagePath = image.path;
              });
              // Upload the image to Firebase Storage
              await _uploadPermitImage(image.path);
            }
          },
          icon: const Icon(Icons.upload_file),
          label: Text(_permitImagePath != null
              ? 'Change Permit Photo'
              : 'Upload Permit Photo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        if (_permitImagePath != null && _permitImageUrl == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text(
                  'Uploading permit photo...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        if (_permitImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Permit photo uploaded successfully',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push<Map<String, OperatingHours>>(
              context,
              MaterialPageRoute(
                builder: (context) => SetOperatingHoursScreen(
                  initialHours: _selectedOperatingHours,
                ),
              ),
            );
            if (result != null) {
              setState(() {
                _selectedOperatingHours = result;
              });
            }
          },
          icon: const Icon(Icons.access_time),
          label: Text(_selectedOperatingHours == null
              ? 'Set Operating Hours'
              : 'Edit Operating Hours'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        if (_selectedOperatingHours != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Operating hours have been set',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBarFeaturesSection() {
    return _buildSectionContainer(
      title: 'Bar Features',
      children: [
        Text(
          'Select the features available at your bar',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableFeatures.map((feature) {
            final isSelected = _selectedFeatures.contains(feature);
            return FilterChip(
              label: Text(feature),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedFeatures.add(feature);
                  } else {
                    _selectedFeatures.remove(feature);
                  }
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
      icon: Icons.local_bar,
    );
  }

  Widget _buildLocationSection() {
    return _buildSectionContainer(
      title: 'Location Details',
      children: [
        PhilippineRegionDropdownView(
          onChanged: (Region? value) {
            setState(() {
              if (region != value) {
                province = null;
                municipality = null;
                barangay = null;
              }
              region = value;
            });
          },
          value: region,
        ),
        const SizedBox(height: 12),
        PhilippineProvinceDropdownView(
          provinces: region?.provinces ?? [],
          onChanged: (Province? value) {
            setState(() {
              if (province != value) {
                municipality = null;
                barangay = null;
              }
              province = value;
            });
          },
          value: province,
        ),
        const SizedBox(height: 12),
        PhilippineMunicipalityDropdownView(
          municipalities: province?.municipalities ?? [],
          onChanged: (value) {
            setState(() {
              if (municipality != value) {
                barangay = null;
              }
              municipality = value;
            });
          },
          value: municipality,
        ),
        const SizedBox(height: 12),
        PhilippineBarangayDropdownView(
          barangays: municipality?.barangays ?? [],
          onChanged: (value) {
            setState(() {
              barangay = value;
            });
          },
          value: barangay,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _streetAddressController,
          decoration: InputDecoration(
            labelText: 'Street Address',
            hintText: 'Enter complete street address',
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Street address is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationPickerScreen(),
                  ),
                );
                if (result != null && result is LatLng) {
                  setState(() {
                    _selectedLocation = result;
                  });
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to get location. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.location_on),
            label: Text(
              _selectedLocation == null
                  ? 'Pick Bar Location on Map'
                  : 'Change Location',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Selected Location: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
      icon: Icons.location_on_outlined,
    );
  }

  Widget _buildAccountTypeCard({
    required String title,
    required IconData icon,
    required String description,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
