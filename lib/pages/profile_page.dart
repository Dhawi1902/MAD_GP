import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'settings_page.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  final void Function(ThemeMode) setTheme;

  ProfilePage({required this.setTheme});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final userData = await _firestoreService.getUserData(user.uid);
        _usernameController.text = userData['username'] ?? 'Username';
        _bioController.text = userData['bio'] ?? 'No bio available';
      } catch (e) {
        print('Error loading user data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data.')),
        );
      }
      setState(() {});
    }
  }

  Future<void> _updateProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;

    String? imageUrl;
    if (_profileImage != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');
        await ref.putFile(_profileImage!);
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload profile image.')),
        );
        return;
      }
    }

    try {
      await _firestoreService.updateUserData(
        user.uid,
        {
          'username': _usernameController.text.trim(),
          'bio': _bioController.text.trim(),
          if (imageUrl != null) 'photoURL': imageUrl,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(setTheme: widget.setTheme),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : (user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : AssetImage('assets/placeholder.png')) as ImageProvider,
                child: _profileImage == null && user?.photoURL == null
                    ? Icon(Icons.camera_alt, size: 30, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 20),

            // Username
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 10),

            // Bio
            TextField(
              controller: _bioController,
              decoration: InputDecoration(labelText: 'Bio'),
              maxLines: 3,
            ),
            SizedBox(height: 20),

            // Email
            Text(
              'Email: ${user?.email ?? 'Not available'}',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 10),

            // Member Since
            Text(
              'Member since: ${user?.metadata.creationTime?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 30),

            // Save Button
            ElevatedButton(
              onPressed: _updateProfile,
              child: Text('Save Profile'),
            ),
            SizedBox(height: 20),

            // Logout Button
            ElevatedButton(
              onPressed: () async {
                await _authService.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text('Log Out'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
