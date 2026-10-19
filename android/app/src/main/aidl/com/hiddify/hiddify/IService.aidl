package com.Outrun VPN.Outrun VPN;

import com.Outrun VPN.Outrun VPN.IServiceCallback;

interface IService {
  int getStatus();
  void registerCallback(in IServiceCallback callback);
  oneway void unregisterCallback(in IServiceCallback callback);
}