import 'package:flutter/material.dart';

import 'create_goal_screen.dart';

class GoalsScreen extends StatelessWidget {
  final String hubId;

  const GoalsScreen({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Group Goals")),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("New Goal"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateGoalScreen(hubId: hubId)),
          );
        },
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag, size: 80, color: Colors.grey),

              SizedBox(height: 24),

              Text(
                "No goals yet",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 12),

              Text(
                "Create your first shared goal\nfor this Hub.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
