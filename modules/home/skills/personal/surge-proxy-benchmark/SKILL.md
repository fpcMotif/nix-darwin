---
name: surge-proxy-benchmark
description: "Procedure for benchmarking Surge proxy nodes, measuring pure destination latencies, and verifying AI/web accessibility."
---

# Surge Proxy Pure Destination Latency Benchmark

Procedure for benchmarking Surge proxy nodes via `surge-cli`, isolating pure node-to-destination latency (subtracting local-to-proxy RTT), and testing multi-target endpoints (APIs, websites, Gemini UI).

## 1. Core Concept & Formula

$$\text{Pure Destination Latency} = \text{Total Measured Time} - \text{Local-to-Proxy Hop (RTT)}$$

- **Local Hop (RTT):** Latency from local client to Surge proxy node measured via `surge-cli --raw test-policy <node>`.
- **Pure Latency:** True round-trip time between the VPN exit IP and destination website.

## 2. Key Surge CLI Commands

```bash
# Get environment & active proxy node
/Applications/Surge.app/Contents/Applications/surge-cli --raw environment

# Switch active global proxy node
/Applications/Surge.app/Contents/Applications/surge-cli --raw set AllProxyModePolicyNameKey="🇯🇵 Japan 01" ProxyGroupSelection.Proxies="🇯🇵 Japan 01" ProxyGroupSelection.AI="🇯🇵 Japan 01"

# Test local-to-proxy latency (TCP & RTT)
/Applications/Surge.app/Contents/Applications/surge-cli --raw test-policy "🇯🇵 Japan 01"

# Test proxy node external IP
/Applications/Surge.app/Contents/Applications/surge-cli --raw test-policy-external-ip "🇯🇵 Japan 01"
```

## 3. Running with `uv`

```bash
# Interactive loop (switch nodes and press Enter)
uv run benchmark_surge.py [extra_urls...]

# Single run with custom targets
uv run benchmark_surge.py --once http://target-ip/ https://example.com

# Automated 8-region batch benchmark (HK, JP, US, UK, DE, IN, ID, BR)
uv run auto_benchmark_all.py [extra_urls...]
```
