---
name: clashmi-to-surge-profile
description: "Convert Clash Mi (Mihomo) subscriptions and node configs on macOS to Surge profiles, including protocol constraints (VLESS vs AnyTLS) and SOCKS5 bridge setup."
---

# Clash Mi to Surge Profile Conversion & Protocol Compatibility Guide

## Clash Mi Storage Architecture on macOS

- **Group Container Directory**: `~/Library/Group Containers/group.com.nebula.clashmi/`
- **Metadata**: `profiles.json` contains subscription links, expiration, remark, update intervals, and custom user-agents (e.g. `ClashMeta/1.19.24; mihomo/1.19.24`).
- **Profile Files**: `profiles/<id>.yaml` contains full node definitions and proxy groups.

## Surge Official Protocol Compatibility Matrix

Surge natively supports:
- `http` / `https`
- `socks5` / `socks5-tls`
- `ss` (Shadowsocks)
- `snell` (v1–v6)
- `vmess`
- `trojan`
- `tuic` / `tuic-v5`
- `hysteria2` (Mac 5.4.0+ / iOS 5.8.0+)
- `anytls` (Mac 6.4.3+ / iOS 5.17.0+)
- `masque` (Mac 6.9.0+ / iOS 5.22.0+)
- `wireguard` / `tailscale`
- `external` (Mac Only)

**Surge does NOT support `vless`**: Any line with `type: vless` causes `Unknown proxy type: vless` (`SGSettingsModelErrorDomain:0`).

## Handling VLESS Subscriptions in Surge

If an airport strictly issues VLESS nodes (e.g. QWQ):
1. **SOCKS5 Upstream Chain (Recommended)**:
   Keep Clash Mi / Mihomo running locally listening on `127.0.0.1:7890`. In Surge profile:
   ```ini
   [Proxy]
   ClashMi = socks5, 127.0.0.1, 7890

   [Proxy Group]
   Proxy = select, ClashMi, DIRECT
   ```
2. **Surge `external` Policy (Mac Only)**:
   Let Surge manage the external proxy binary directly:
   ```ini
   [Proxy]
   LocalCore = external, exec = "/Applications/Clash Mi.app/Contents/MacOS/Clash Mi", local-port = 7890, udp-relay = true
   ```

## Handling AnyTLS Subscriptions in Surge

If an airport uses AnyTLS (e.g. `primehelix` / `nx`):
Surge 6.4.3+ supports AnyTLS natively:
```ini
[Proxy]
NodeName = anytls, server.address, 7347, password=pwd, sni=sni.domain.com, skip-cert-verify=true, tls=true
```

## Surge Managed Profiles Location
- Local profile directory: `~/Library/Application Support/Surge/Profiles/`
