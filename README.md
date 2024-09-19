<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

Offline First Sync for Flutter
This package provides a robust, offline-first syncing solution for Flutter applications, focusing on Firestore and Sembast integrations. It leverages the Domain-Driven Design (DDD) principle, allowing developers to customize their syncing logic for specific needs.

# Features

Offline Capability: Ensures seamless user experience even without internet access by caching data locally with Sembast.
Real-time Synchronization: Automatically synchronizes local data with Firestore when a network connection becomes available.
DDD-Based Architecture: Promotes modularity and maintainability by separating concerns and offering a framework for custom syncing logic.
Pre-built Integrations: Offers pre-implemented syncing logic for Firestore and Sembast, providing a solid foundation for most use cases.
Customizable Framework: Allows developers to extend or modify syncing logic for specific data types or implement custom conflict resolution strategies.

# Prerequisites
Flutter project with a functioning Dart environment.
Firebase project with Firestore enabled.
Sembast dependency added to your pubspec.yaml file.

# Getting started

## Installation
1. Add the package to your pubspec.yaml dependencies:

    `YAML
    dependencies:
    offline_first_sync: ^1.0.0 (replace with your package version)`

2. Run flutter pub get to install the package.

## Usage

1. Configuration:

    Set up your Firestore configuration within your application.
    Initialize Sembast with your desired database path.
2. Domain Model:

    Define your domain entities and their corresponding repositories.
3. Sync Logic:

    Implement custom syncing logic for your domain entities, leveraging the provided framework and building upon the pre-implemented Firestore and Sembast syncing logic.
4. Usage:

    Utilize the provided APIs to initiate syncing, query data, and manage conflicts.

```dart
import 'package:offline_first_sync/offline_first_sync.dart';

class MyEntity {
  final String id;
  final String data;

  MyEntity(this.id, this.data);
}

Future<void> syncData() async {
  // Initialize Firestore and Sembast
  final firestore = FirebaseFirestore.instance;
  final sembastStore = await Sembast.getInstance('my_database.db');

  // Define your syncing logic 
  final syncManager = OfflineFirstSyncManager<MyEntity>(
    firestoreCollection: 'my_entities',
    sembastStore: sembastStore,
    converter: MyEntityConverter(),
  );

  await syncManager.sync(); // Triggers synchronization
}

class MyEntityConverter extends OfflineFirstSyncConverter<MyEntity> {
  @override
  MyEntity fromMap(Map<String, dynamic> map) => MyEntity(map['id'], map['data']);

  @override
  Map<String, dynamic> toMap(MyEntity entity) => {'id': entity.id, 'data': entity.data};
}
```

# Additional information

## Documentation:

Full API documentation is yet to be created. View the read me on github.

## Contributing:

We welcome contributions to this package! Please refer to the CONTRIBUTING.md file for guidelines.

## Issues:

Please report any bugs or feature requests on the GitHub repository: https://github.com/lhengl/sync_service.

## Support:

For further assistance or questions, feel free to create an issue on GitHub. We will do our best to respond promptly.
