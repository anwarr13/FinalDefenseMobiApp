import 'package:flutter/material.dart';

class Bar {
  final String name;
  final String description;
  final String imageUrl;

  Bar({required this.name, required this.description, required this.imageUrl});
}

class ListOfBarsScreen extends StatelessWidget {
  // Sample list of bars
  final List<Bar> bars = [
    Bar(
      name: 'Taway Bar',
      description: 'A cozy bar in Ipil with a nice ambiance.',
      imageUrl: 'https://example.com/taway_bar.jpg', // Sample image URL
    ),
    Bar(
      name: 'Junk Bar',
      description: 'A relaxed bar with a great selection of drinks.',
      imageUrl: 'https://example.com/junk_bar.jpg',
    ),
    Bar(
      name: 'Katribu Bar',
      description: 'A modern bar offering local delicacies and cocktails.',
      imageUrl: 'https://example.com/katribu_bar.jpg',
    ),
    // Add more bars as needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('List of Bars'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: List.generate(bars.length, (index) {
            final bar = bars[index];
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.grey[300],
                ),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      image: DecorationImage(
                        image: NetworkImage(bar.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(
                    bar.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    bar.description,
                  ),
                  onTap: () {
                    // You can add functionality when a bar is tapped, e.g., navigate to a detailed page
                    print("Tapped on ${bar.name}");
                  },
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
