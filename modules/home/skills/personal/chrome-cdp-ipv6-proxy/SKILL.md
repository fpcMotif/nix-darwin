---
name: chrome-cdp-ipv6-proxy
description: "Forward IPv4 127.0.0.1:9222 to IPv6 [::1]:9222 for agent-browser CDP connection"
---

# Chrome CDP IPv6 to IPv4 Port Proxying

When connecting `agent-browser --cdp 9222` to a user-spawned Chrome instance (e.g. Chrome Beta) on macOS where DevTools is listening on IPv6 `[::1]:9222`:

## Problem
`agent-browser --cdp 9222` resolves `localhost:9222` to IPv4 `127.0.0.1:9222`. If Chrome bound exclusively to IPv6 `[::1]:9222`, connection attempts to `127.0.0.1:9222` fail with connection refused.

## Recipe
Run a lightweight Python socket proxy in background to forward IPv4 `127.0.0.1:9222` traffic to IPv6 `[::1]:9222`:

```python
import socket, threading

def proxy_stream(src, dst):
    try:
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        src.close()
        dst.close()

def handle_client(client_soc):
    try:
        target_soc = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        target_soc.connect(('::1', 9222))
        t1 = threading.Thread(target=proxy_stream, args=(client_soc, target_soc))
        t2 = threading.Thread(target=proxy_stream, args=(target_soc, client_soc))
        t1.start()
        t2.start()
    except Exception:
        client_soc.close()

def run_proxy():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 9222))
    server.listen(5)
    while True:
        client, addr = server.accept()
        threading.Thread(target=handle_client, args=(client,)).start()

threading.Thread(target=run_proxy, daemon=True).start()
```

Once running, `agent-browser --cdp 9222` connects cleanly to the Chrome instance.
