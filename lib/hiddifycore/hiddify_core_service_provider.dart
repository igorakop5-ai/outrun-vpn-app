import 'package:Outrun VPN/core/directories/directories_provider.dart';
import 'package:Outrun VPN/core/notification/in_app_notification_controller.dart';
import 'package:Outrun VPN/Outrun VPNcore/Outrun VPN_core_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'Outrun VPN_core_service_provider.g.dart';

@Riverpod(keepAlive: true, dependencies: [AppDirectories, inAppNotificationController])
Outrun VPNCoreService Outrun VPNCoreService(Ref ref) {
  return Outrun VPNCoreService(ref);
}
