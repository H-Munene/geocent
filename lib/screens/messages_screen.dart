import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_tut/models/unmapped_message.dart';
import 'package:mapbox_tut/widgets/unmapped_message_tile.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<UnmappedMessage>> groupedMessages = {
      'Today': [
        UnmappedMessage(
          sender: 'Munene',
          status:
              'Needs categorization.Needs categorization.Needs categorization.Needs .',
          timeAgo: '16m ago',
          amount: 'Ksh 1,200',
        ),
        UnmappedMessage(
          sender: 'Zuku Fiber',
          status: 'Needs mapping. Needs mappingNeeds mappingNeeds mapping',
          timeAgo: '2h ago',
          amount: 'Ksh 4,500',
        ),
      ],
      'Yesterday': [
        UnmappedMessage(
          sender: 'KPLC Prepaid',
          status: 'Needs categorization',
          timeAgo: '1d ago',
          amount: 'Ksh 500',
        ),
        UnmappedMessage(
          sender: 'Naivas Supermarket',
          status: 'Needs mapping',
          timeAgo: '1d ago',
          amount: 'Ksh 3,240',
        ),
      ],
      'Older': [
        UnmappedMessage(
          sender: 'Jumia Tech',
          status: 'Needs mapping',
          timeAgo: '3d ago',
          amount: 'Ksh 15,600',
        ),
        UnmappedMessage(
          sender: 'Uber Trip',
          status: 'Needs categorization',
          timeAgo: '1w ago',
          amount: 'Ksh 850',
        ),
      ],
    };

    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withOpacity(0.8),
        border: null,
        middle: Text(
          'Messages',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: groupedMessages.entries.expand((entry) {
            final String title = entry.key;
            final List<UnmappedMessage> messages = entry.value;

            return [
              _SectionHeader(title: title),
              ...messages.asMap().entries.map((messageEntry) {
                final int index = messageEntry.key;
                final UnmappedMessage message = messageEntry.value;
                final bool isLast = index == messages.length - 1;

                return UnmappedMessageTile(
                  message: message,
                  showDivider: !isLast,
                );
              }),
            ];
          }).toList(),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
    );
  }
}
