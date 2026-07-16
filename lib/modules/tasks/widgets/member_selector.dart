import 'package:flutter/material.dart';
import '../../../core/models/member_option.dart';

class MemberSelector extends StatelessWidget {
  final List<MemberOption> members;
  final String? selectedUserId;
  final ValueChanged<MemberOption?> onChanged;

  const MemberSelector({
    super.key,
    required this.members,
    required this.selectedUserId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedUserId,
      decoration: const InputDecoration(
        labelText: "Assign to",
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text("Unassigned"),
        ),
        ...members.map(
          (member) => DropdownMenuItem<String>(
            value: member.userId,
            child: Text(member.userName),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          onChanged(null);
          return;
        }

        final member = members.firstWhere(
          (m) => m.userId == value,
        );

        onChanged(member);
      },
    );
  }
}