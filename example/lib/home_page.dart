import 'package:example/registry_view.dart';
import 'package:example/remote_view.dart';
import 'package:example/service_a_view.dart';
import 'package:example/service_b_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_page_controller.dart';

class HomePage extends GetView<HomePageController> {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return controller.obx(
      (widget) {
        return DefaultTabController(
            initialIndex: 0,
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Sync Service Example'),
                bottom: TabBar(tabs: [
                  Tab(child: Text('Remote')),
                  Tab(child: Text(Constants.serviceA)),
                  Tab(child: Text(Constants.serviceB)),
                  Tab(child: Text('Registry')),
                ]),
              ),
              body: TabBarView(
                children: [
                  RemoteView(),
                  ServiceAView(),
                  ServiceBView(),
                  RegistryView(),
                ],
              ),
            ));
      },
    );
  }
}
