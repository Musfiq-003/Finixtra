# Related Work Analysis: GetConnect

## Document Analyzed
**Title:** A Multimodal, Infrastructure-Free Offline Emergency Communication System for Mobile Devices Using Adaptive Hybrid Mesh Networking (GetConnect)
**Context:** This research provides the foundational methodology for FINIXTRA's offline-first, infrastructure-free communication and synchronization features.

## 1. Core Problem & Solution
- **Problem:** Centralized communication infrastructures (cellular networks, internet) often fail during natural disasters or emergencies, rendering modern mobile applications useless.
- **Solution:** **GetConnect**, a decentralized, peer-to-peer (P2P) emergency communication system built for smartphones. It operates completely independently of cellular or internet infrastructure.

## 2. Key Technologies & Architecture
- **Hybrid Mesh Networking:** 
  - **Bluetooth Low Energy (BLE):** Used for low-power continuous peer discovery.
  - **Wi-Fi Direct:** Used for high-bandwidth data transfer (e.g., establishing TCP connections on port 8080).
- **Store-and-Forward Mechanism:** Enables delay-tolerant networking (DTN). If a direct route isn't available, messages are buffered and opportunistically forwarded when peers are encountered.
- **Cross-Platform Implementation:** Built using **Flutter** (Dart codebase) for deployment on both Android and iOS devices without requiring root access.
- **Security:** End-to-end encryption using **AES-256-GCM** to ensure the privacy and integrity of communications.

## 3. Adaptive Routing Protocol
The system employs an adaptive distance-vector routing protocol tailored for resource-constrained, dynamic environments.
- **Routing Metric:** Evaluates routes based on distance (hops), link quality, and the battery level of the next-hop node.
  `metric = 50 * d + 100 * (1 - q) + 100 * (1 - b)`
- **Loop Prevention:** Uses split horizon, maximum hop limits (10 hops), sequence numbers, and path vectors.

## 4. Performance Metrics
- **Delivery Rate:** ~93.4% average message delivery.
- **Latency:** Median 2-hop latency of 1.8 seconds.
- **Energy Efficiency:** Idle power draw of 42 mAh/hr, allowing for 24+ hours of operation on a standard smartphone battery (2500 mAh).
- **Voice Quality:** PESQ score of 3.2+ over up to 3 hops, which is highly viable for emergency voice communication.

## 5. Relevance & Application to FINIXTRA
FINIXTRA is a microservices-based FinTech platform. By adapting the GetConnect methodology, FINIXTRA can achieve true **Offline-First Resilience**:
- **Offline Wallet Synchronization:** Users can securely conduct transactions (e.g., double-entry ledger updates) even without internet connectivity, relying on the mesh network to propagate transaction data securely.
- **Eventual Consistency:** The store-and-forward architecture can be modified to queue offline financial transactions. Once any node in the mesh regains internet access to the FINIXTRA API Gateway, it can act as an uplink, syncing the offline ledger with the central backend.
- **Encrypted Payloads:** The AES-256-GCM encryption aligns perfectly with the strict security requirements of financial transactions, ensuring that intermediary relays cannot view the plaintext transaction details.

## 6. Limitations to Address in FINIXTRA
- **iOS Background Limits:** iOS restricts background BLE/Wi-Fi operations heavily. FINIXTRA's app will need careful state management to handle iOS background suspension.
- **Scalability:** The paper notes scaling boundaries (20-100 devices). For larger dense environments (e.g., a stadium or city center), FINIXTRA may need hierarchical clustering or dedicated uplink gateways.
