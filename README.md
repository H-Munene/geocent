# Geocent

Geocent is a smart personal finance application designed for geo-verified transaction and visit tracking. It automatically parses financial SMS messages (e.g., M-PESA, Equity Bank), links them to real-world GPS coordinates, and provides an interactive map-based view of spending habits alongside intelligent auto-categorization.

## Getting Started

Follow these instructions to set up Geocent on your local development machine.

### Prerequisites

- **Flutter SDK**: [Install Flutter](https://docs.flutter.dev/get-started/install) (latest stable version recommended).
- **Git**: For cloning the repository.
- **Mapbox Account**: You will need a Mapbox account to get an access token for the maps. [Sign up here](https://account.mapbox.com/).

### Installation

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/your-username/geocent.git
    cd geocent
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Configure Environment Variables**:
    Create a `.env` file in the root directory and add your Mapbox Public Access Token:
    ```bash
    cp .env.example .env
    ```
    Edit `.env` and replace the placeholder with your token:
    ```env
    MAPBOX_ACCESS_TOKEN=your_mapbox_public_access_token
    ```

### Platform Setup

#### Android

To download the Mapbox SDK, you need to configure a secret token in your global `gradle.properties` file.

1.  Generate a **Secret Access Token** from your Mapbox account with the `DOWNLOADS:READ` scope.
2.  Add the following to your `~/.gradle/gradle.properties` (or `C:\Users\<User>\.gradle\gradle.properties` on Windows):
    ```properties
    MAPBOX_DOWNLOADS_TOKEN=your_secret_mapbox_download_token
    ```

#### iOS

Reading messages on IOS is not supported

### Running the App

Connect a device or start an emulator/simulator, then run:

```bash
flutter run
```

## Core Features

1.  **SMS Parsing & Auto-Tracking**: Automatically detects incoming financial SMS messages, extracting merchant, amount, and timestamp.
2.  **Geo-Verification**: Captures the device's GPS location when a transaction occurs and links it to the transaction.
3.  **Advanced Mapbox UI**: High-performance Mapbox implementation with custom GPU-accelerated expressions and dual-layer annotations.
4.  **Intelligent Auto-Categorization**: Automatically assigns categories to recurring merchants based on user history.
5.  **Real-time Budgeting**: Set spending limits per category for daily, weekly, or monthly periods.
6.  **Interactive Analytics**: Searchable interface for all messages and comprehensive spending analytics.

## Supported SMS Formats

Geocent currently supports parsing for the following providers:
- **M-PESA**: Sent payments, paid bills, and airtime purchases.
- **Equity Bank**: Card authorization messages (KES and USD).

## Tech Stack

- **Framework**: Flutter
- **Mapping**: Mapbox Maps Flutter (Native GPU Expressions)
- **Local Database**: SQLite (sqflite)
- **Background Processing**: flutter_background_service
- **State Management**: Provider (ChangeNotifier)
- **Icons**: Hugeicons & Cupertino Icons

## Documentation

For a deeper dive into the architecture and database logic:
- [Technical Architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [Database Schema & Logic](docs/DATABASE_SCHEMA.md)
- [Design Principles](DESIGN.md)
