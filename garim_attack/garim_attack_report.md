# Garim Attack - App Structure & UI Report

## 1. Overview

**Garim Attack** is a specialized Flutter application designed as an "Attacker Console" for deepfake security testing. It simulates a threat actor's environment, allowing users to generate deepfakes in real-time within a peer-to-peer video call context. The app combines real-time communication (WebRTC) with a WebSocket-based signaling and control layer.

## 2. Technical Architecture

### 2.1 Technology Stack

- **Framework**: Flutter (Supports Mobile, Web, and Desktop)
- **State Management**: Riverpod (NotifierProvider pattern)
- **Routing**: GoRouter
- **Communication**:
  - **Signaling/Control**: Socket.IO (v1.1 Protocol)
  - **Video Streaming**: Flutter WebRTC (Peer-to-Peer)
- **Deepfake Generation**: Server-side processing via Socket.IO (image frames emitted to server, processed frames received back).

### 2.2 Key Components & Data Flow

The application is structured around a central dashboard that coordinates three main data streams:

1.  **Signaling & Logic (`SocketNotifier`)**:
    - Manages connection to the Python backend (`garim-signaling-server`).
    - Handles "Virtual Number" registration and "Secure Dialer" logic.
    - transmits video frames for server-side deepfake processing (`emitDeepfake`).
    - Receives processed frames and face coordinates (`face_rect`).

2.  **Video Streaming (`WebRTCNotifier`)**:
    - Manages the local camera feed and remote peer connection.
    - Handles SDP Offer/Answer exchange and ICE Candidates.
    - Controls video source switching (Camera vs. Deepfake injection).

3.  **UI Orchestration (`DashboardScreen`)**:
    - Responsive layout that adapts to screen size.
    - Binds the logic providers to the visual components.

---

## 3. User Interface (UI) Design

### 3.1 Design Language

The app employs a distinct **"Cyber/Hacker" aesthetic** to fit the persona of an attacker.

- **Color Palette**:
  - **Background**: Deep Black (`#000000`, `#101010`) for a terminal feel.
  - **Primary (Success/Safe)**: Neon Green (`#00FF41`) used for text, borders, and active states.
  - **Secondary (Danger/Action)**: Bright Red (`#FF0000`) for deepfake activation and critical alerts.
- **Typography**: `Courier` (Monospaced) font used throughout to simulate a command-line interface.
- **Visual Elements**:
  - Semi-transparent borders.
  - Terminal-style log feeds.
  - Data visualization graphs (Line charts for latency).

### 3.2 Screen Structure (Dashboard)

The main interface (`DashboardScreen.dart`) is divided into three functional panels (on Desktop):

#### A. Left Panel: Control & Monitor

_Focus: Attack Configuration and System Status_

1.  **Source Identity**: A panel to upload/select the "Source Face" used for swapping.
2.  **Attack Controls**:
    - **Deepfake Button**: A prominent toggle to start/stop the deepfake generation loop.
    - **Effects**: Toggles for "Mosaic" (pixelation) and "Beauty" filters.
3.  **System Monitor**:
    - **Latency Graph**: Real-time line chart visualizing network delay (`FlChart`).
    - **Terminal Logs**: A scrolling list of system events (socket messages, errors, status updates).

#### B. Center Panel: Video Operations

_Focus: Real-time Visual Feedback_

1.  **Main Feed**: Displays the local attacker's video stream.
    - **Deepfake Overlay**: When active, the processed deepfake face is overlaid onto the original video stream using coordinates (`Rect`) received from the server.
2.  **Remote Feed**: A Picture-in-Picture (PiP) style overlay showing the target's video stream (the victim).
3.  **HUD Elements**: Corner brackets (`_buildCorner`) to frame the view, enhancing the "camera viewfinder" or "targeting system" look.

#### C. Right Panel: Station & Communications

_Focus: Identity and Connection_

1.  **Station Identity**: Displays the randomly generated "Virtual Number" (e.g., `010-8293-XXXX`).
2.  **Secure Dialer**:
    - A custom numeric keypad for dialing target phone numbers.
    - "Call" and "End" buttons that trigger WebRTC signaling sequences.
    - Digital display showing the formatted phone number.

## 4. Key Workflows

1.  **Connection**: User enters a target number via the Secure Dialer and initiates a call. The app sends a `call:request` via WebRTC.
2.  **Attack Setup**: User uploads a source face image in the Left Panel.
3.  **Execution**: User presses "DEEPFAKE START". The app begins capturing frames, sending them to the server, and rendering the returned deepfake face over the real-time video feed.
