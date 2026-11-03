import 'package:flutter/material.dart';

import 'leave_requests_page.dart';
import 'pass_slips_page.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(children: [
        Padding(
          padding: EdgeInsets.only(left: 16, top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [Tab(text: 'Leave'), Tab(text: 'Pass slips')],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(children: [LeaveRequestsPage(), PassSlipsPage()]),
        ),
      ]),
    );
  }
}