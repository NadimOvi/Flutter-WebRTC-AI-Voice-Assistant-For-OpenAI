# Flutter WebRTC AI Voice Assistant

This project demonstrates a real-time AI voice assistant built with Flutter and OpenAI’s Realtime API using WebRTC.  
It allows users to talk to an AI model in real-time, receive voice responses, and display the transcribed text on screen.  
The application shows how to integrate real-time audio streaming, WebRTC, and OpenAI’s Realtime API in a Flutter project.

---

## Overview

The app establishes a WebRTC connection between the Flutter client and OpenAI’s Realtime API.  
It captures microphone input, streams it to the AI model, and plays back the AI-generated audio response while showing the transcribed text.  
This is useful for building natural, conversational AI interfaces directly in mobile or web applications.

---

## Features

- Real-time audio streaming between user and AI  
- AI-generated speech output and text display  
- WebRTC-based low-latency communication  
- Permission handling for microphone access  
- Simple and modern Flutter UI  
- Organized code structure with clean architecture  

---


## Getting Started

### Prerequisites

Make sure you have the following installed on your system:

- Flutter SDK (3.10.0 or newer)
- Android Studio or Visual Studio Code
- An OpenAI API key with access to the Realtime API
- A mobile device or emulator with microphone access

---

### Installation

Clone the repository:

```bash
git clone https://github.com/yourusername/flutter-webrtc-ai-assistant.git
cd flutter-webrtc-ai-assistant

flutter pub get

### Configuration

Before running the app, configure your OpenAI API connection.  
You will need a backend endpoint that provides an **ephemeral token** to the Flutter app.

In your `openai_server.dart`, replace the placeholder with your backend endpoint:

```dart
class OpenAIService {
  static Future<String> getEphemeralToken() async {
    // Retrieve the ephemeral token from your backend server
    // Example:
    // final response = await http.get(Uri.parse("https://your-server.com/token"));
    // return json.decode(response.body)["token"];
    return "";
  }
}
