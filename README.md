# FastWrt

FastWrt is an **idempotent automation framework for OpenWrt**, engineered to provide robust, repeatable, and modular network configuration for routers and embedded devices. It ensures that all network settings are deployed **consistently and identically every time the script is run**, regardless of previous configurations or system state.

---

## 🔧 **Technical Overview**

### ▶️ **Design principles**

1. **Full idempotence**  
   Every execution flushes all relevant existing settings before applying the defined configuration. This guarantees a known clean state and prevents legacy or conflicting configurations.  
   ✅ *Same result on every run, every device.*

2. **Modular architecture**  
   The framework is structured into **dedicated modules** for each functional area (VLANs, interfaces, firewall, SSH, VPN preparation, certificates). This improves maintainability, readability, and scalability for future expansion.

3. **Explicit configuration-driven deployment**  
   All settings derive directly from structured configuration definitions within the script or external config files, ensuring clarity and auditability.

---

### ⚙️ **Current functionality**

FastWrt automates:

- **🔀 VLAN configurations**  
  Creates and configures VLANs for traffic segregation, defining network zones such as management, core LAN, IoT, and guest networks. Each VLAN is assigned its dedicated virtual interface and firewall zone to ensure isolation.

- **🌐 Network interfaces**  
  Creates and binds physical and virtual interfaces to their respective VLANs and zones, ensuring correct Layer 2 and Layer 3 topology.

- **🛡️ Firewall zones and rules**  
  Defines firewall zones per network segment with strict inter-zone policies. Implements:

  - Secure minimal default rules  
  - Port forwarding templates (e.g. WireGuard)  
  - SSH access restrictions per zone

- **🔒 SSH bindings**  
  Configures Dropbear to bind only to **defined internal networks (typically core LAN)** for secure management access, explicitly preventing exposure on WAN.

- **🔐 WireGuard VPN preparation**  
  Creates port forwarding and base firewall rules for WireGuard, and sets up a structure to deploy full VPN configurations seamlessly.

- **📜 TLS certificate preparation**  
  Includes functionality to automate installation and management of internal TLS certificates for encrypted local services, future-proofing for Zero Trust or internal PKI models.

---

### 🔁 **Idempotence implementation**

FastWrt enforces full idempotence through:

- Flushing existing configurations in affected areas (network, firewall, interfaces) before deployment
- Deploying the entire configuration from scratch on every run
- Validating applied settings where applicable to confirm operational consistency

This makes FastWrt suitable for **CI/CD pipelines**, large-scale automated deployments, and scenarios requiring guaranteed configuration drift prevention.

---

## 🚀 **Development status**

Currently, FastWrt is tailored for the:

- **GL.iNet Flint 2 (GL-MT6000)** running OpenWrt.

However, its **modular structure is designed for straightforward adaptation** to other compatible devices. This adaptation should be a trivial task for users with:

- Basic to intermediate knowledge of Linux systems  
- Understanding of networking concepts (VLAN, firewall zones, routing)  
- Ability to read and modify shell scripts

Multi-device abstraction is an active development goal in the roadmap.

---

## 🗺️ **Roadmap**

- [ ] **Multi-device support** with automatic detection and profile application
- [ ] **Additional modules** for dynamic service deployment (e.g. DNS, DHCP templates, HAProxy)
- [ ] **Device-specific profile generation** for instant deployable configs
- [ ] **CI/CD integration** for automated testing and validation of configurations before deployment

---

## 📝 **License**

This project is licensed under the [MIT License](LICENSE).

---

### 💡 **Summary**

FastWrt is an advanced automation framework that combines **robustness, clarity, and operational safety** through true idempotence and modular architecture, enabling professional-grade OpenWrt deployments with minimal manual intervention.
"""
