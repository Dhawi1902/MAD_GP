import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../models/project.dart';

class HomePage extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.pushReplacementNamed(context, '/login'));
    }

    return Scaffold(
      appBar: AppBar(title: Text('My Tasks')),
      body: StreamBuilder<List<Task>>(
        stream: _firestoreService.getAssignedTasks(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No tasks assigned.'));
          }

          final tasks = snapshot.data!;
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return StreamBuilder<Project?>(
                stream: _firestoreService.getProjectById(task.projectId),
                builder: (context, projectSnapshot) {
                  if (projectSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final project = projectSnapshot.data;
                  final projectName = project?.name ?? 'Unknown Project';

                  return _buildTaskCard(context, task, projectName);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, String projectName) {
    return Card(
      child: ListTile(
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project: $projectName'),
            Text('Priority: ${task.priority}'),
            Text('Due Date: ${task.dueDate?.toLocal().toString().split(' ')[0] ?? 'No due date'}'),
            Text('Status: ${task.status}'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          // Handle navigation to task details if needed
        },
      ),
    );
  }
}