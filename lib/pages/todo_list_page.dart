import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';
import '../models/project.dart';
import 'project_settings_page.dart';

class TodoListPage extends StatefulWidget {
  @override
  _TodoListPageState createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Center(child: Text('User not logged in.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Projects'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showCreateProjectDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: _firestoreService.getProjectsForUser(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print('No projects found for user: ${_currentUser!.uid}');
            return Center(child: Text('No projects found.'));
          }

          final projects = snapshot.data!;

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildProjectCard(context, project);
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, Project project) {
    return Card(
      child: ListTile(
        title: Text(project.name),
        subtitle:
            Text(project.isPersonal ? 'Personal Project' : 'Sharable Project'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!project.isPersonal)
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProjectSettingsPage(project: project),
                    ),
                  );
                },
              ),
            Icon(Icons.arrow_forward),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailPage(project: project),
            ),
          );
        },
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Project'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'Project Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _firestoreService.createProject(
                  name,
                  _currentUser!.uid,
                  isPersonal: false, // Sharable project by default
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project name cannot be empty!')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}

class ProjectDetailPage extends StatelessWidget {
  final Project project;

  const ProjectDetailPage({Key? key, required this.project}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: project.isPersonal
            ? [] // Personal projects have no delete or invite options
            : [
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _confirmDeleteProject(context, project),
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(child: TaskList(project: project)),
          if (!project.isPersonal)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _showCreateTaskDialog(context, project),
                child: Text('Create Task'),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, Project project) {
    if (project.isPersonal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Personal projects cannot be deleted.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Project'),
        content: Text(
            'Are you sure you want to delete this project? All associated tasks will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteProject(project.id);
              Navigator.pop(context);
              Navigator.pop(context); // Navigate back to the project list
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog(BuildContext context, Project project) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Task Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isNotEmpty && description.isNotEmpty) {
                await FirestoreService().createTask(
                  project.id, // Use the current project ID
                  title,
                  description,
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Task title and description cannot be empty!')),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}

class TaskList extends StatelessWidget {
  final Project project;

  const TaskList({Key? key, required this.project}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: FirestoreService().getProjectTasks(project.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No tasks found.'));
        }

        final tasks = snapshot.data!;
        return ListView(
          children: tasks
              .map((task) => _buildTaskTile(context, task, project))
              .toList(),
        );
      },
    );
  }

  Widget _buildTaskTile(BuildContext context, Task task, Project project) {
    return ListTile(
      title: Text(task.title),
      subtitle: Text(task.description),
      trailing: !project.isPersonal && task.assignee == null
          ? ElevatedButton(
              onPressed: () {
                FirestoreService()
                    .claimTask(task.id, FirebaseAuth.instance.currentUser!.uid);
              },
              child: Text('Claim'),
            )
          : null,
    );
  }
}
