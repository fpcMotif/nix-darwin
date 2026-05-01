## 2024-05-18 - NixOS Sudo Hardening
**Vulnerability:** Sudo was not restricted to the wheel group in NixOS configuration.
**Learning:** By default, any user can attempt to run `sudo`, which exposes the system to local privilege escalation vulnerabilities if `sudo` has flaws.
**Prevention:** Set `security.sudo.execWheelOnly = true;` to restrict `sudo` execution exclusively to users in the `wheel` group.

## 2024-05-18 - SSH Known Hosts Not Hashed
**Vulnerability:** The SSH configuration explicitly disabled `hashKnownHosts` (`hashKnownHosts = false;`).
**Learning:** Disabling `hashKnownHosts` stores IP addresses and hostnames in plaintext within `~/.ssh/known_hosts`. If an attacker gains local access, this provides them with a ready-made list of targets for lateral movement across the network.
**Prevention:** Set `hashKnownHosts = true;` (or omit the setting as it defaults to true in modern SSH) in SSH configurations to ensure hostnames and IP addresses are cryptographically hashed, mitigating reconnaissance efforts.
