import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/call_provider.dart';

class DialScreen extends ConsumerStatefulWidget {
  const DialScreen({super.key});

  @override
  ConsumerState<DialScreen> createState() => _DialScreenState();
}

class _DialScreenState extends ConsumerState<DialScreen> {
  String _phoneNumber = '';

  void _onNumberPress(String value) {
    if (_phoneNumber.length < 15) {
      setState(() {
        _phoneNumber += value;
      });
    }
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  void _onCall() {
    if (_phoneNumber.isNotEmpty) {
      debugPrint('Calling $_phoneNumber');
      // Trigger outgoing call logic
      ref.read(callProvider.notifier).startCall(_phoneNumber);
      context.go('/calling');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Display Area (Flexible height)
            Expanded(
              flex: 3,
              child: Container(
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Text(
                  _phoneNumber,
                  style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Keypad Area
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRow(['1', '2', '3'], subText: ['', 'ABC', 'DEF']),
                    _buildRow(['4', '5', '6'], subText: ['GHI', 'JKL', 'MNO']),
                    _buildRow(
                      ['7', '8', '9'],
                      subText: ['PQRS', 'TUV', 'WXYZ'],
                    ),
                    _buildRow(
                      ['*', '0', '#'],
                      subText: ['', '+', ''],
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),

            // Call Button Area
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Empty placeholder to balance spacing
                    const SizedBox(width: 64),

                    GestureDetector(
                      onTap: _onCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Backspace Button
                    SizedBox(
                      width: 64,
                      child: IconButton(
                        icon: const Icon(
                          Icons.backspace_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: _onBackspace,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    List<String> keys, {
    required List<String> subText,
    bool isLast = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(keys.length, (index) {
        return _DialButton(
          text: keys[index],
          sub: subText[index],
          onTap: () => _onNumberPress(keys[index]),
        );
      }),
    );
  }
}

class _DialButton extends StatelessWidget {
  final String text;
  final String? sub;
  final VoidCallback onTap;

  const _DialButton({required this.text, this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent, // Ensure touch works
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (sub != null && sub!.isNotEmpty)
              Text(
                sub!,
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
          ],
        ),
      ),
    );
  }
}
