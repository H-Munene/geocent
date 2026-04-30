import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Messages',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      child: Center(
        child: Text(
          'Unmapped & Uncategorized Messages',
          style: GoogleFonts.spaceGrotesk(),
        ),
      ),
    );
  }
}
