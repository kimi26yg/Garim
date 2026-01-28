# Instructions: Garim Eye V2 - Attacker Dashboard

## 1. [CRITICAL] Fixed Instruction: Maintain Latest Code & Architecture

- **Documentation**: You MUST use **Context7** to reference the most recent documentation.
- **Architecture**: **ALWAYS** use **Riverpod (v2.x)** for state management and **GoRouter** for structural design and navigation.
- **Modern Standards**: Use the latest stable syntax. Strictly avoid deprecated methods (e.g., use `withValues` instead of `withOpacity`).
- **Clean Code**: Ensure all providers and controllers are modular and follow a clean architecture pattern.

## 2. Project Context & Layout

- **App Name**: Garim Eye V2 - Attacker Dashboard (Hacker-style UI)
- **UI Layout**:
  - **Left (Main)**: Large 9:16 aspect ratio viewport (Attacker's local camera).
  - **Top Right Overlay**: A 1/4 size 9:16 overlay (Remote target's video).
  - **Right Sidebar (Attack Console)**:
    - Image upload section and thumbnail preview.
    - [Deepfake Start], [Network Stress], [Beauty Effect] buttons.
    - Real-time terminal log console at the bottom.

## 3. Technical Specifications

- **Responsive Ratio**: Utilize `AspectRatio` and `BoxFit.cover` to maintain the 9:16 ratio regardless of window size.
- **Communication**: Design a structure to emit Socket.io events for each control button.
- **Role**: Acts as a "Control Tower"; heavy model inference (inswapper) is handled by the Python backend.
