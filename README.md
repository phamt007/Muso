# Muso

A high-performance, API-independent iOS music player built with Flutter. Muso streams audio directly from YouTube using custom extraction techniques, featuring native background playback and a custom pre-warming engine designed to achieve zero-latency track transitions.

## Features
* **Zero-Latency Pre-warmer:** Custom background caching engine that listens to native player streams and silently extracts the subsequent track's URL prior to the current track's completion, eliminating network loading gaps.
* **Native iOS Integration:** Full background audio support and lock-screen media controls utilizing `audio_session` and `just_audio_background`. Employs custom iOS `User-Agent` header routing to comply with Apple's native AVPlayer stream requirements.
* **Algorithmic Search:** Queries are dynamically filtered and sorted by view count to prioritize high-quality, official audio tracks.
* **Persistent Library:** Local storage architecture utilizing `shared_preferences` to persist user playlists, dynamic queues, and track metadata across sessions.
* **Continuous Delivery:** Configured for automated compilation and deployment to Apple TestFlight via GitHub Actions.

## Technical Stack

* **Framework:** Flutter / Dart
* **Audio Engine:** `just_audio`, `just_audio_background`, `audio_session`
* **Stream Extraction:** `youtube_explode_dart`
* **Local Storage:** `shared_preferences`

## System Architecture

### The Pre-warming Engine
The primary bottleneck in audio extraction is manifest retrieval latency. Rhythmic resolves this by utilizing an event-driven `positionStream` listener. When the active track reaches `duration - 3 seconds`, the application spins up a background isolate to fetch the highest-bitrate MP4 stream for the next queued track. Upon the current track's completion, the native player swaps to the cached URL instantly.

### Stream Routing & Compliance
To ensure Apple's native AVPlayer accepts the scraped URLs, Rhythmic strictly filters the extraction manifest for `muxed` MP4 containers and injects an iOS-specific `User-Agent` into the HTTP headers before passing the URI to the native audio engine.

## Getting Started

### Prerequisites
* Flutter SDK (`>=3.10.8`)
* macOS environment (required for iOS compilation)
* Xcode & CocoaPods

### Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/muso.git](https://github.com/yourusername/muso.git)
