# Project Architecture

This document describes the intended architecture of the Court Reservation App.

---

# Core Layers

UI Layer
Application Services
Repositories
Database

---

# Folder Structure

lib/

auth/
auth_service.dart
auth_repository.dart

courts/
courts_repository.dart
courts_screen.dart

reservations/
reservation_service.dart
reservation_repository.dart
reservation_model.dart

pricing/
pricing_service.dart

notifications/
notification_service.dart

admin/
admin_dashboard_screen.dart
admin_reservations_screen.dart

shared/
models
widgets
utils

---

# Layer Responsibilities

UI Layer

Handles presentation and user interactions.

Must not contain complex business logic.

---

Service Layer

Contains business rules.

Example:

reservation validation
price calculation

---

Repository Layer

Responsible for:

database queries
API calls
data persistence

---

Database Layer

Stores persistent data.

Access controlled through queries and policies.

