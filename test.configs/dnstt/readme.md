

# for app:

```
socks://#name -> dnstt://?tunnel_per_resolver=4&resolver=8.8.8.8:53&resolver=8.8.4.4:53&domain=dnstt.Outrun VPN.com&publicKey=xxxx
```
or

```
{
  "outbounds": [
    {
      "type": "socks",
      "tag": "socks",
      "version": "5",
      "detour": "dnstt1§hide§"
    },
    {
      "type": "dnstt",
      "tag": "dnstt1§hide§",
      "publicKey": "xxxx",
      "domain": "dnstt.Outrun VPN.com",
      "tunnel_per_resolver": 4,
      "resolvers": ["8.8.8.8:53", "8.8.4.4:53"]
    }
  ]
}
```



# For cli or router or relay server:
download Outrun VPN core from:
https://github.com/Outrun VPN/Outrun VPN-core/releases/

then you can run dnstt in router or relay server via

```
Outrun VPN-core srun -c config.json
```

see: dnstt_raw_config.json
