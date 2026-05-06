# Geocent

## Project Purpose
Geocent is a smart personal finance application designed for geo-verified transaction and visit tracking. It automatically parses financial SMS messages (e.g., M-PESA, Equity Bank), links them to real-world GPS coordinates, and provides an interactive map-based view of spending habits alongside intelligent auto-categorization.

## Tech Stack
- **Framework**: Flutter
- **Mapping**: Mapbox Maps Flutter (utilizing Native GPU Expressions)
- **Local Database**: SQLite (sqflite)
- **Background Processing**: flutter_background_service
- **State Management**: Provider (ChangeNotifier)

## Core Features
1. **SMS Parsing & Auto-Tracking**: Automatically detects incoming financial SMS messages in the foreground and background, extracting merchant, amount, and timestamp.
2. **Geo-Verification**: Automatically captures the device's GPS location when a transaction occurs and links it to the transaction, creating a map of spending habits.
3. **Advanced Mapbox UI**: Features a highly performant Mapbox implementation with custom GPU-accelerated zoom expressions, dual-layer annotations (dots and callouts), and dynamic style switching.
4. **Intelligent Auto-Categorization**: Learns from user inputs to automatically assign categories to recurring merchants without manual intervention.
5. **Interactive Analytics & Messaging**: Provides a searchable, filterable interface for all messages with bulk categorization capabilities, alongside spending limit analytics.

## Documentation
For an in-depth look at the architecture and logic of Geocent, please refer to the following documentation:
- [Technical Architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [Database Schema & Logic](docs/DATABASE_SCHEMA.md)
