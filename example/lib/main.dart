import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'firestore_hard_deletion/firestore_hard_deletion.dart';
import 'firestore_soft_deletion/firestore_soft_deletion.dart';

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
                FirestoreHardDeletionPage(),
                binding: BindingsBuilder(() {
                  Get.put(FirestoreHardDeletionController());
                }),
              );
            },
            child: const Text('Firestore Deletion Registry Implementation'),
          ),
          OutlinedButton(
            onPressed: () {
              Get.to(
                FirestoreSoftDeletionPage(),
                binding: BindingsBuilder(() {
                  Get.put(FirestoreSoftDeletionController());
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
