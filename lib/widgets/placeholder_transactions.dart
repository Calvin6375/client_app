import 'package:flutter/material.dart';

class PlaceholderTransactions extends StatelessWidget {
  const PlaceholderTransactions({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => ListTile(
          leading: CircleAvatar(backgroundColor: Colors.grey.shade300),
          title: Container(height: 10, color: Colors.grey.shade300),
          subtitle: Container(
            height: 10,
            width: 100,
            color: Colors.grey.shade200,
          ),
          trailing: Container(
            height: 10,
            width: 60,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
