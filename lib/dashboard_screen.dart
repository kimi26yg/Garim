import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'video_feed_section.dart';
import 'control_sidebar.dart';
import 'providers/socket_provider.dart';
import 'providers/webrtc_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to next frame to ensure providers are ready and we don't trigger state updates during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSignaling();
    });
  }

  void _setupSignaling() {
    final socketNotifier = ref.read(socketProvider.notifier);
    final webRTCNotifier = ref.read(webRTCProvider.notifier);
    final socket = socketNotifier.socket;

    // Use Protocol v1.1 Listeners
    webRTCNotifier.setupSignalListeners(socket);
  }

  @override
  Widget build(BuildContext context) {
    final socketState = ref.watch(socketProvider);
    final myPhone = socketState.myPhoneNumber ?? "INITIALIZING...";

    return Scaffold(
      appBar: AppBar(
        title: Text("GEYE ADMIN STATION: $myPhone",
            style: const TextStyle(
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              color: Colors.black,
            )),
        backgroundColor: Theme.of(context).colorScheme.primary,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop / Wide Mode
          if (constraints.maxWidth > 850) {
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.black,
                    child: const Center(child: VideoFeedSection()),
                  ),
                ),
                Container(
                  width: 400,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  child: const ControlSidebar(), // Now safe (no Spacer)
                ),
              ],
            );
          } else {
            // Mobile / Narrow Mode
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Video Feed (Top)
                  Container(
                    color: Colors.black,
                    // Use 3:4 or 9:16 aspect ratio or max height
                    height: 600,
                    width: double.infinity,
                    child: const Center(child: VideoFeedSection()),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  // Controls (Bottom)
                  const ControlSidebar(),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
