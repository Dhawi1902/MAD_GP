import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/project.dart';

class ProjectSettingsPage extends StatefulWidget {
  final Project project;

  const ProjectSettingsPage({Key? key, required this.project}) : super(key: key);

  @override
  _ProjectSettingsPageState createState() => _ProjectSettingsPageState();
}

class _ProjectSettingsPageState extends State<ProjectSettingsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  Color? _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.project.cardColor ?? Colors.grey;
  }

  Future<void> _addUser(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    try {
      await _firestoreService.inviteUserToProject(widget.project.id, email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding user: $e')),
      );
    }
  }

  Future<void> _deleteProject() async {
    if (widget.project.isPersonal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personal projects cannot be deleted.')),
      );
      return;
    }

    try {
      final shouldDelete = await _confirmDelete();
      if (shouldDelete) {
        await _firestoreService.deleteProject(widget.project.id);
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting project: $e')),
      );
    }
  }

  Future<bool> _confirmDelete() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete Project'),
            content: Text('Are you sure you want to delete the project "${widget.project.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _setCardColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _firestoreService.updateProject(widget.project.id, {'cardColor': color.value});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Project Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          // Add User Section
          ListTile(
            title: Text('Add User'),
            subtitle: TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'User Email'),
            ),
            trailing: IconButton(
              icon: Icon(Icons.add),
              onPressed: () async {
                if (_emailController.text.trim().isNotEmpty) {
                  await _firestoreService.addUserToProject(
                    widget.project.id,
                    _emailController.text.trim(),
                  );
                  setState(() {}); // Refresh UI
                }
              },
            ),
          ),
          Divider(),

          // Team Members
          ListTile(
            title: Text('Team Members'),
            subtitle: FutureBuilder<List<Map<String, dynamic>>>(
              future: _firestoreService.getProjectParticipants(widget.project.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No team members found.');
                }

                final members = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: members.map((member) {
                    return Text(
                      '${member['email']} (${member['role']})',
                      style: TextStyle(fontSize: 16),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Divider(),

          // Set Card Colour
          ListTile(
            title: Text('Set Card Colour'),
            subtitle: Row(
              children: [
                GestureDetector(
                  onTap: () => _setCardColor(Colors.blue),
                  child: CircleAvatar(backgroundColor: Colors.blue),
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _setCardColor(Colors.green),
                  child: CircleAvatar(backgroundColor: Colors.green),
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _setCardColor(Colors.red),
                  child: CircleAvatar(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
          Divider(),

          // Delete Project
          ListTile(
            title: Text('Delete Project'),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteProject,
            ),
          ),
        ],
      ),
    );
  }
}
