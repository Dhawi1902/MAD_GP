import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/todoList'),
              child: Text('To-Do List'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: Text('Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
