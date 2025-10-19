import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webrtc_realtime_aibot/openai_server.dart';
import 'dart:math' as math;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  String emphemeralKey = "";
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  RTCDataChannel? dataChannel;

  // --- UI state ---
  List<Map<String, dynamic>> messages = [];
  bool isSpeaking = false;
  late AnimationController _voiceAnimController;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _voiceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _voiceAnimController.dispose();
    super.dispose();
  }

  void requestPermissions() async {
    await Permission.microphone.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text(
          "AI Voice Assistant",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // --- Chat messages list ---
            Expanded(
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg["role"] == "user";
                  return Align(
                    alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF10A37F)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg["text"] ?? "",
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // --- Voice visualization when AI speaks ---
            if (isSpeaking)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedBuilder(
                  animation: _voiceAnimController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final scale = math.sin(_voiceAnimController.value *
                            math.pi *
                            (index + 1)) *
                            0.5 +
                            0.5;
                        return Container(
                          width: 6,
                          height: 30 * scale + 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10A37F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),

            // --- Buttons section ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        startWebRtcSession();
                      },
                      icon: const Icon(Icons.mic, color: Colors.white),
                      label: const Text(
                        "Start Call",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10A37F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        stopWebRtcConnection();
                      },
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      label: const Text(
                        "End Call",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> startWebRtcSession() async {
    try {
      stopWebRtcConnection();
      emphemeralKey = await OpenAIService.getEphemeralToken();
      print("Key Generated: $emphemeralKey");

      // Setup peer connection
      final configs = {
        'iceServers': [
          {
            'urls': [
              'stun:stun1.1.google.com:19302',
              'stun:stun2.1.google.com:19302',
            ]
          }
        ],
        'sdpSemantics': 'unified-plan',
        'enableDtlsSrtp': true
      };

      peerConnection = await createPeerConnection(configs);
      final mediaConfigs = {
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
        'video': false
      };
      localStream = await navigator.mediaDevices.getUserMedia(mediaConfigs);

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      RTCDataChannelInit dataChannelInit = RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30
        ..protocol = 'sctp'
        ..negotiated = false;

      dataChannel = await peerConnection?.createDataChannel(
          "oai-events", dataChannelInit);
      if (dataChannel != null) {
        setupDataChannel();
      }

      final offer = await peerConnection?.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await peerConnection?.setLocalDescription(offer!);

      const baseUrl = 'https://api.openai.com/v1/realtime';
      const model = 'gpt-4o-realtime-preview-2024-12-17';
      var request = http.Request('POST', Uri.parse('$baseUrl?model=$model'));
      request.body = offer?.sdp?.replaceAll('\r\n', '\n') ?? '';
      request.headers.addAll({
        'Authorization': 'Bearer $emphemeralKey',
        'Content-Type': 'application/sdp',
        'Accept': 'application/sdp',
      });

      final response = await http.Client().send(request);
      final sdpResponse = await response.stream.bytesToString();

      final answer = RTCSessionDescription(sdpResponse, 'answer');
      await peerConnection?.setRemoteDescription(answer);

      setState(() {
        isSpeaking = true;
      });

      print('✅ WebRTC connection established.');
    } catch (e) {
      print("Error starting WebRTC session: $e");
    }
  }

  void setupDataChannel() {
    dataChannel?.onMessage = (message) {
      try {
        final data = json.decode(message.text);
        if (data['type'] == "response.audio_transcript.done") {
          setState(() {
            messages.add({"role": "ai", "text": data['transcript']});
          });
        } else if (data['item'] != null &&
            data['item']['content'] is List &&
            data['item']['content'][0]['text'] != null) {
          setState(() {
            messages.add({
              "role": "ai",
              "text": data['item']['content'][0]['text'],
            });
          });
        }
      } catch (e) {
        print('Error processing AI message: $e');
      }
    };
  }

  void stopWebRtcConnection() async {
    setState(() {
      isSpeaking = false;
    });
    if (dataChannel != null) {
      await dataChannel?.close();
      dataChannel = null;
    }
    if (localStream != null) {
      localStream?.getTracks().forEach((track) => track.stop());
      localStream = null;
    }
    if (peerConnection != null) {
      await peerConnection?.close();
      peerConnection = null;
    }
    print("🔴 WebRTC Connection terminated successfully");
  }
}
