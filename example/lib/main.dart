import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'firestore_deletion_registry/firestore_deletion_registry.dart';
import 'firestore_soft_delete/firestore_soft_delete.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(GetMaterialApp(
      title: 'Sync Service Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    ));
  }, (error, stacktrace) {
    developer.log('[ZonedGuarded]', error: error, stackTrace: stacktrace);
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Service Example'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () {
              Get.to(
                FirestoreDeletionRegistryPage(),
                binding: BindingsBuilder(() {
                  Get.put(FirestoreDeletionRegistryController());
                }),
              );
            },
            child: const Text('Firestore Deletion Registry Implementation'),
          ),
          OutlinedButton(
            onPressed: () {
              Get.to(
                FirestoreSoftDeletePage(),
                binding: BindingsBuilder(() {
                  Get.put(FirestoreSoftDeleteController());
                }),
              );
            },
            child: const Text('Firestore Soft Delete Implementation'),
          ),
        ],
      ),
    );
  }
}
