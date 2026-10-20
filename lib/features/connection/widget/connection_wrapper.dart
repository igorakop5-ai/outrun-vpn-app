import 'package:flutter/material.dart';
import 'package:outrun_vpn/core/localization/translations.dart';
import 'package:outrun_vpn/core/notification/in_app_notification_controller.dart';
import 'package:outrun_vpn/features/connection/notifier/connection_notifier.dart';
import 'package:outrun_vpn/features/profile/notifier/active_profile_notifier.dart';
import 'package:outrun_vpn/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:outrun_vpn/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionWrapper extends StatefulHookConsumerWidget {
  const ConnectionWrapper(this.child, {super.key});

  final Widget child;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ConnectionWrapperState();
}

class _ConnectionWrapperState extends ConsumerState<ConnectionWrapper> with AppLogger {
  @override
  Widget build(BuildContext context) {
    ref.listen(connectionNotifierProvider, (_, _) {});

    ref.listen(configOptionNotifierProvider, (previous, next) async {
      if (next case AsyncData(value: true)) {
        final t = ref.read(translationsProvider).requireValue;
        ref
            .read(inAppNotificationControllerProvider)
            .showInfoToast(
              t.connection.reconnectMsg,
              // actionText: t.connection.reconnect,
              // callback: () async {
              //   await ref
              //       .read(connectionNotifierProvider.notifier)
              //       .reconnect(await ref.read(activeProfileProvider.future));
              // },
            );
        await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
      }
    });

    return widget.child;
  }
}
