import 'dart:io';

import 'package:outrun_vpn/Outrun VPNcore/core_interface/core_interface.dart';
import 'package:outrun_vpn/Outrun VPNcore/core_interface/core_interface_desktop.dart';
import 'package:outrun_vpn/Outrun VPNcore/core_interface/core_interface_mobile.dart';

CoreInterface getCoreInterface() {
  if (Platform.isAndroid || Platform.isIOS) {
    return CoreInterfaceMobile();
  }
  return CoreInterfaceDesktop();
}
