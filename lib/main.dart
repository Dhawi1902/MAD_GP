import 'package:flutter/material.dart';
import 'pages/homepage.dart';
import 'pages/todo_list_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/todoList': (context) => TodoListPage(),
        '/profile': (context) => ProfilePage(),
      },
    );
  }
}
