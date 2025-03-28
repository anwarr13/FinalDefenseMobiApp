import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Add padding inside the screen
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
                height: 5), // Adjust space from the top of the screen
            // Image at the top
            Container(
              width: 120, // Set the width of the image
              height: 120, // Set the height of the image
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(60), // Circular border for the image
                image: const DecorationImage(
                  image: AssetImage(
                      'assets/Programmer.jpg'), // Replace with your image asset path
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Jervis John Alan F. Villacora',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20), // Space between image and text
            const Text(
              'This is the About page. Here, you can find information about the app developer.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
