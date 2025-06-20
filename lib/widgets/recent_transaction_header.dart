import 'package:flutter/material.dart';

class RecentTransactionsHeader extends StatelessWidget {
  const RecentTransactionsHeader({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "Recent transactions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Spacer(),
        TextButton(onPressed: () {}, child: Text("See all")),
      ],
    );
  }
}
