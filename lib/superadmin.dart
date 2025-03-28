import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_form/main.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'services/notification_service.dart';
import 'services/email_service.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final EmailService _emailService = EmailService();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // Initial camera position (Ipil, Zamboanga Sibugay)
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(7.7844, 122.5872),
    zoom: 14.5,
  );

  Future<void> _handleApproval(String userId, bool isApproved) async {
    try {
      // Get the bar data from pending_bars
      final barDoc =
          await _firestore.collection('pending_bars').doc(userId).get();
      if (!barDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bar not found')),
        );
        return;
      }

      final barData = barDoc.data()!;

      // Get the user's email and name
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userEmail = userData?['email'] as String?;
      final ownerName = userData?['name'] as String? ?? 'Bar Owner';

      if (isApproved) {
        // Ensure location data is properly formatted
        GeoPoint? locationGeoPoint;
        final locationData = barData['location'];
        if (locationData is GeoPoint) {
          locationGeoPoint = locationData;
        } else if (locationData is Map<String, dynamic>) {
          final lat = locationData['latitude'];
          final lng = locationData['longitude'];
          if (lat != null && lng != null) {
            locationGeoPoint = GeoPoint(lat.toDouble(), lng.toDouble());
          }
        }

        if (locationGeoPoint == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Bar location data is missing or invalid'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Move to approved bars collection with all data including location
        await _firestore.collection('bars').doc(userId).set({
          ...barData,
          'approved': true,
          'status': 'approved',
          'approvalDate': FieldValue.serverTimestamp(),
          'location': locationGeoPoint,
          'address': {
            'street': barData['address']?['street'] ?? '',
            'barangay': barData['address']?['barangay'] ?? '',
            'municipality': barData['address']?['municipality'] ?? '',
            'province': barData['address']?['province'] ?? '',
            'region': barData['address']?['region'] ?? '',
          },
        });

        // Send approval email to bar owner
        if (userEmail != null) {
          try {
            await _emailService.sendApprovalEmail(
              recipientEmail: userEmail,
              barName: barData['barName'] ?? 'Your Bar',
              ownerName: ownerName,
            );
          } catch (emailError) {
            print('Failed to send approval email: $emailError');
            // Don't show error to admin as the main approval process succeeded
          }
        }

        // Update user status
        await _firestore.collection('users').doc(userId).update({
          'approved': true,
          'status': 'approved',
        });

        // Add new marker for the approved bar
        final location =
            LatLng(locationGeoPoint.latitude, locationGeoPoint.longitude);
        final fullAddress = [
          barData['address']?['street'] ?? '',
          barData['address']?['barangay'] ?? '',
          barData['address']?['municipality'] ?? '',
          barData['address']?['province'] ?? '',
        ].where((part) => part.isNotEmpty).join(', ');

        final marker = Marker(
          markerId: MarkerId(userId),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: barData['barName'] ?? 'Unnamed Bar',
            snippet: fullAddress,
          ),
          onTap: () {
            _showBarDetails(barData);
          },
        );

        setState(() {
          _markers.add(marker);
        });

        // Center map on the new bar location
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(location, 15),
        );

        // Send detailed approval notification
        await _notificationService.sendNotification(
          userId: userId,
          title: '🎉 Registration Approved!',
          message:
              '''Congratulations! Your bar registration for "${barData['barName']}" has been approved.

You now have access to all bar owner features:
• Manage your bar profile
• Update operating hours and features
• View customer reviews and ratings
• Respond to customer feedback
• Access analytics and insights

Get started by logging in to your account.''',
          type: 'approval',
        );

        // Send welcome notification
        await _notificationService.sendNotification(
          userId: userId,
          title: '👋 Welcome to the Community!',
          message:
              '''Welcome to our bar owner community! Here are some tips to get started:

1. Complete your bar profile
2. Add high-quality photos
3. Set your operating hours
4. Update your featured amenities
5. Engage with customer reviews

Need help? Contact our support team anytime.''',
          type: 'welcome',
        );
      } else {
        // Update user status as rejected
        await _firestore.collection('users').doc(userId).update({
          'status': 'rejected',
          'rejectionDate': FieldValue.serverTimestamp(),
        });

        // Send rejection notification
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Registration Rejected',
          message:
              'Your bar registration has been rejected. Please contact support for more information.',
          type: 'rejection',
        );
      }

      // Delete from pending collection
      await _firestore.collection('pending_bars').doc(userId).delete();

      // Refresh the approved bars list and map
      await _loadApprovedBars();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApproved
                  ? 'Bar approved successfully'
                  : 'Bar registration rejected',
            ),
            backgroundColor: isApproved ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'LGU Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 28,
                ),
                onPressed: () async {
                  await _auth.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => WelcomeScreen()),
                    );
                  }
                },
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.blue.shade700,
            indicatorWeight: 3,
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: [
              Tab(
                icon:
                    Icon(Icons.pending_actions, color: Colors.orange.shade700),
                text: 'Pending',
              ),
              Tab(
                icon: Icon(Icons.check_circle, color: Colors.green.shade700),
                text: 'Approved',
              ),
              Tab(
                icon: Icon(Icons.map, color: Colors.red.shade700),
                text: 'Map View',
              ),
            ],
          ),
        ),
        body: Container(
          color: Colors.grey.shade50,
          child: TabBarView(
            children: [
              _buildPendingTab(),
              _buildApprovedTab(),
              _buildMapTab(),
            ],
          ),
        ),
      ),
    );
  }

  // Future<void> _logFailedLoginAttempt(String userId) async {
  //   final directory = await getApplicationDocumentsDirectory();
  //   final logDir = Directory('${directory.path}/failed_logins');
  //   if (!await logDir.exists()) {
  //     await logDir.create(recursive: true);
  //   }
  //   final logFile = File('${logDir.path}/failed_logins.txt');
  //   final timestamp = DateTime.now().toIso8601String();
  //   await logFile.writeAsString(
  //       'Failed login attempt for userId: $userId at $timestamp\n',
  //       mode: FileMode.append);
  // }

  /// Checks if the current user is a superadmin. If not, logs a failed
  /// login attempt and redirects to the NotAuthorizedScreen.
  // Future<void> _checkSuperAdminAccess() async {
  //   User? user = _auth.currentUser;
  //   if (user != null) {
  //     DocumentSnapshot userDoc =
  //         await _firestore.collection('users').doc(user.uid).get();
  //     if (userDoc.exists && userDoc['role'] == 'superadmin') {
  //       // User is a superadmin, allow access
  //       return;
  //     }
  //   }
  //   // Log failed attempt if not superadmin
  //   if (user != null) {
  //     await _logFailedLoginAttempt(user.uid);
  //   }
  //   // Redirect or show error if not superadmin
  //   if (mounted) {
  //     Navigator.of(context).pushReplacement(
  //       MaterialPageRoute(builder: (context) => const LoginScreen()),
  //     );
  //   }
  // }

  Future<void> _handleBarStatus(String barId, bool enable) async {
    try {
      // Update bar status in Firestore
      await _firestore.collection('bars').doc(barId).update({
        'isActive': enable,
      });

      // Update marker visibility
      setState(() {
        _markers = _markers.map((marker) {
          if (marker.markerId.value == barId) {
            return marker.copyWith(
              visibleParam: enable,
            );
          }
          return marker;
        }).toSet();
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enable ? 'Bar enabled successfully' : 'Bar disabled successfully',
            ),
            backgroundColor: enable ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating bar status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    //_checkSuperAdminAccess();
    _loadApprovedBars();
  }

  Future<void> _loadApprovedBars() async {
    setState(() => _isLoading = true);
    try {
      final QuerySnapshot barSnapshot = await _firestore
          .collection('bars')
          .where('status', isEqualTo: 'approved')
          .get();

      Set<Marker> newMarkers = {};

      for (var doc in barSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final locationData = data['location'];
        GeoPoint? geoPoint;

        // Skip disabled bars
        if (data['isActive'] == false) continue;

        if (locationData is GeoPoint) {
          geoPoint = locationData;
        } else if (locationData is Map<String, dynamic>) {
          final lat = locationData['latitude'];
          final lng = locationData['longitude'];
          if (lat != null && lng != null) {
            geoPoint = GeoPoint(lat.toDouble(), lng.toDouble());
          }
        }

        if (geoPoint != null) {
          final location = LatLng(geoPoint.latitude, geoPoint.longitude);

          // Create full address
          final String fullAddress = [
            data['streetAddress'] ?? '',
            data['barangay'] ?? '',
            data['municipality'] ?? '',
            data['province'] ?? '',
          ].where((part) => part.isNotEmpty).join(', ');

          // Create marker with red color
          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: location,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: data['barName'] ?? 'Unnamed Bar',
              snippet: fullAddress,
            ),
            onTap: () {
              _showBarDetails(data);
            },
          );
          newMarkers.add(marker);
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
          _isLoading = false;
        });

        // Show all markers on the map
        if (newMarkers.isNotEmpty && _mapController != null) {
          _showAllMarkers();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading approved bars: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('pending_bars').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending bar registrations',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = docs[index].id;
            final String ownerName =
                '${data['firstName'] ?? ''} ${data['middleName'] ?? ''} ${data['lastName'] ?? ''}'
                    .trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.all(16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.store,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      data['barName'] ?? 'Unnamed Bar',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Owner: $ownerName',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PENDING REVIEW',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      _buildInfoRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: data['email'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Contact',
                        value: data['contactNumber'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        icon: Icons.location_city,
                        label: 'Address',
                        value: [
                          data['address']?['street'] ?? '',
                          data['address']?['barangay'] ?? '',
                          data['address']?['municipality'] ?? '',
                          data['address']?['province'] ?? '',
                        ].where((s) => s.isNotEmpty).join(', '),
                      ),
                      // _buildInfoRow(
                      //   icon: Icons.numbers,
                      //   label: 'Business Permit Number',
                      //   value: data['permitNumber'] ?? 'N/A',
                      // ),
                      _buildInfoRow(
                        icon: Icons.description,
                        label: 'Description',
                        value: data['description'] ?? 'No description provided',
                      ),
                      if (data['features']?.isNotEmpty ?? false)
                        _buildInfoRow(
                          icon: Icons.star,
                          label: 'Features',
                          value: (data['features'] as List<dynamic>).join(', '),
                        ),
                      if (data['permitImagePath'] != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Business Permit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showPermitImage(
                            data['permitImagePath'],
                            data['barName'] ?? 'Unnamed Bar',
                          ),
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    data['permitImagePath'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: Colors.red.shade400,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: Icon(
                              Icons.close,
                              color: Colors.red.shade600,
                              size: 20,
                            ),
                            label: Text(
                              'Decline',
                              style: TextStyle(
                                color: Colors.red.shade600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _handleApproval(userId, false),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.check,
                              size: 20,
                            ),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _handleApproval(userId, true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPermitImage(String imageUrl, String barName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$barName - Business Permit',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading permit image...',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[400],
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Failed to load permit image',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showPermitImage(imageUrl, barName);
                              },
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bars')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No approved bars yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String ownerName =
                '${data['firstName'] ?? ''} ${data['middleName'] ?? ''} ${data['lastName'] ?? ''}'
                    .trim();
            final approvalDate = (data['approvalDate'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.all(16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.store,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      data['barName'] ?? 'Unnamed Bar',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Owner: $ownerName',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (approvalDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Approved on: ${approvalDate.toLocal().toString().split(' ')[0]}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'APPROVED',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      _buildInfoRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: data['email'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Contact',
                        value: data['contactNumber'] ?? 'N/A',
                      ),
                      _buildInfoRow(
                        icon: Icons.location_city,
                        label: 'Address',
                        value: [
                          data['address']?['street'] ?? '',
                          data['address']?['barangay'] ?? '',
                          data['address']?['municipality'] ?? '',
                          data['address']?['province'] ?? '',
                        ].where((s) => s.isNotEmpty).join(', '),
                      ),
                      // _buildInfoRow(
                      //   icon: Icons.numbers,
                      //   label: 'Business Permit Number',
                      //   value: data['permitNumber'] ?? 'N/A',
                      // ),
                      _buildInfoRow(
                        icon: Icons.description,
                        label: 'Description',
                        value: data['description'] ?? 'No description provided',
                      ),
                      if (data['features']?.isNotEmpty ?? false)
                        _buildInfoRow(
                          icon: Icons.star,
                          label: 'Features',
                          value: (data['features'] as List<dynamic>).join(', '),
                        ),
                      if (data['permitImagePath'] != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Business Permit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showPermitImage(
                            data['permitImagePath'],
                            data['barName'] ?? 'Unnamed Bar',
                          ),
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    data['permitImagePath'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: Colors.red.shade400,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(
                              data['isActive'] == false
                                  ? Icons.play_arrow
                                  : Icons.pause,
                              size: 20,
                            ),
                            label: Text(data['isActive'] == false
                                ? 'Enable Bar'
                                : 'Disable Bar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: data['isActive'] == false
                                  ? Colors.green.shade600
                                  : Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _handleBarStatus(
                                docs[index].id, data['isActive'] == false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('bars')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading map: ${snapshot.error}',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadApprovedBars,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Update markers when data changes
        if (snapshot.hasData) {
          Set<Marker> newMarkers = {};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final locationData = data['location'];
            GeoPoint? geoPoint;

            if (locationData is GeoPoint) {
              geoPoint = locationData;
            } else if (locationData is Map<String, dynamic>) {
              final lat = locationData['latitude'];
              final lng = locationData['longitude'];
              if (lat != null && lng != null) {
                geoPoint = GeoPoint(lat.toDouble(), lng.toDouble());
              }
            }

            if (geoPoint != null) {
              final location = LatLng(geoPoint.latitude, geoPoint.longitude);

              // Create full address
              final String fullAddress = [
                data['streetAddress'] ?? '',
                data['barangay'] ?? '',
                data['municipality'] ?? '',
                data['province'] ?? '',
              ].where((part) => part.isNotEmpty).join(', ');

              // Create marker with red color
              final marker = Marker(
                markerId: MarkerId(doc.id),
                position: location,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: data['barName'] ?? 'Unnamed Bar',
                  snippet: fullAddress,
                ),
                onTap: () {
                  _showBarDetails(data);
                },
              );
              newMarkers.add(marker);
            }
          }

          // Update markers
          _markers = newMarkers;

          // Show all markers if map controller is ready
          if (_mapController != null && newMarkers.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 100), () {
              _showAllMarkers();
            });
          }
        }
        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_markers.isNotEmpty) {
                  _showAllMarkers();
                }
              },
              markers: _markers,
              mapType: MapType.normal,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: false,
              mapToolbarEnabled: true,
              compassEnabled: true,
              trafficEnabled: false,
              buildingsEnabled: true,
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            // Add refresh button
            Positioned(
              left: 16,
              top: 16,
              child: FloatingActionButton(
                heroTag: 'refresh',
                mini: true,
                child: const Icon(Icons.refresh),
                onPressed: _loadApprovedBars,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBarDetails(Map<String, dynamic> barData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  barData['barName'] ?? 'Unnamed Bar',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Operating Hours: ${barData['operatingHours'] ?? 'Not specified'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact: ${barData['contactNumber'] ?? 'Not provided'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Address: ${[
                    barData['streetAddress'] ?? '',
                    barData['barangay'] ?? '',
                    barData['municipality'] ?? '',
                    barData['province'] ?? '',
                  ].where((part) => part.isNotEmpty).join(', ')}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Features:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (barData['features'] as List<dynamic>? ?? [])
                      .map((feature) => Chip(
                            label: Text(feature.toString()),
                            backgroundColor: Colors.red.shade100,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    LatLngBounds bounds = _getBounds(_markers);
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  LatLngBounds _getBounds(Set<Marker> markers) {
    double? minLat, maxLat, minLng, maxLng;

    for (Marker marker in markers) {
      if (minLat == null || marker.position.latitude < minLat) {
        minLat = marker.position.latitude;
      }
      if (maxLat == null || marker.position.latitude > maxLat) {
        maxLat = marker.position.latitude;
      }
      if (minLng == null || marker.position.longitude < minLng) {
        minLng = marker.position.longitude;
      }
      if (maxLng == null || marker.position.longitude > maxLng) {
        maxLng = marker.position.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return DefaultTabController(
  //     length: 3,
  //     child: Scaffold(
  //       appBar: AppBar(
  //         title: const Text(
  //           'LGU Dashboard',
  //           style: TextStyle(
  //             fontWeight: FontWeight.bold,
  //             fontSize: 24,
  //           ),
  //         ),
  //         backgroundColor: Colors.white,
  //         elevation: 0,
  //         actions: [
  //           Container(
  //             margin: const EdgeInsets.only(right: 8),
  //             child: IconButton(
  //               icon: const Icon(
  //                 Icons.logout_rounded,
  //                 color: Colors.red,
  //                 size: 28,
  //               ),
  //               onPressed: () async {
  //                 await _auth.signOut();
  //                 if (mounted) {
  //                   Navigator.of(context).pushReplacement(
  //                     MaterialPageRoute(builder: (context) => LoginScreen()),
  //                   );
  //                 }
  //               },
  //             ),
  //           ),
  //         ],
  //         bottom: TabBar(
  //           indicatorColor: Colors.blue.shade700,
  //           indicatorWeight: 3,
  //           labelColor: Colors.blue.shade700,
  //           unselectedLabelColor: Colors.grey,
  //           labelStyle: const TextStyle(
  //             fontWeight: FontWeight.bold,
  //             fontSize: 16,
  //           ),
  //           tabs: [
  //             Tab(
  //               icon:
  //                   Icon(Icons.pending_actions, color: Colors.orange.shade700),
  //               text: 'Pending',
  //             ),
  //             Tab(
  //               icon: Icon(Icons.check_circle, color: Colors.green.shade700),
  //               text: 'Approved',
  //             ),
  //             Tab(
  //               icon: Icon(Icons.map, color: Colors.red.shade700),
  //               text: 'Map View',
  //             ),
  //           ],
  //         ),
  //       ),
  //       body: Container(
  //         color: Colors.grey.shade50,
  //         child: TabBarView(
  //           children: [
  //             _buildPendingTab(),
  //             _buildApprovedTab(),
  //             _buildMapTab(),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
}
