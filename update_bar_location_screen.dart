import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpdateBarLocationScreen extends StatefulWidget {
  final String barId;
  final LatLng initialLocation;

  const UpdateBarLocationScreen({
    Key? key,
    required this.barId,
    required this.initialLocation,
  }) : super(key: key);

  @override
  State<UpdateBarLocationScreen> createState() => _UpdateBarLocationScreenState();
}

class _UpdateBarLocationScreenState extends State<UpdateBarLocationScreen> {
  late GoogleMapController _mapController;
  late LatLng _selectedLocation;
  bool _isUpdating = false;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _updateMarker();
  }

  void _updateMarker() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _selectedLocation = newPosition;
            });
          },
        ),
      };
    });
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _updateMarker();
    });
  }

  Future<void> _updateBarLocation() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final firestore = FirebaseFirestore.instance;
      
      // Update the location in Firestore
      await firestore.collection('bars').doc(widget.barId).update({
        'location': GeoPoint(_selectedLocation.latitude, _selectedLocation.longitude),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Bar Location'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
          ),
          // Instructions overlay at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Update Bar Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Drag the marker or tap anywhere on the map to set your bar\'s location',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _updateBarLocation,
        label: _isUpdating
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Updating...'),
                ],
              )
            : const Text('Update Location'),
        icon: _isUpdating ? null : const Icon(Icons.save),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
