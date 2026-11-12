# ADR-0001: Native Swift app with whisper.cpp, no Rust layer

- **Status**: Accepted
- **Date**: 2026-11-12

## Context

We considered React Native, NativeScript, a Rust core (`whisper-rs`) and native Swift. Hard constraints: the keyboard extension
must be native and stay small, keyboards can't record audio, and App Groups, Keychain, WidgetKit and AppIntents are Apple APIs.

## Decision

- Write the app, keyboard and widgets in Swift/SwiftUI.
- Use whisper.cpp's official prebuilt iOS XCFramework, a C API, called directly from Swift (`App/WhisperEngine.swift`).
- Don't add Rust for now.

## Consequences

- A single toolchain (Xcode). No FFI code generation and no cross-compiling Rust for `aarch64-apple-ios`.
- Speed and accuracy are the same as with `whisper-rs`, because both run whisper.cpp.
- If the laptop Leap Whisper core is Rust, shared logic (mode prompts, text cleanup, provider clients) can later move into a Rust
  crate exposed with UniFFI. Inference stays in whisper.cpp. That needs a new ADR.
