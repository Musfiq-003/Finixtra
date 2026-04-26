# FINIXTRA: Initial Project Plan & Architecture Roadmap

## 1. Executive Summary
**FINIXTRA** is a next-generation, microservices-based FinTech platform. Its defining feature is the integration of the **GetConnect methodology**—an adaptive, hybrid mesh networking system—enabling true offline-first, infrastructure-free transaction communication. This ensures users can conduct secure financial operations (e.g., wallet transfers) even during internet or cellular outages.

## 2. Core Objectives
1. **Develop a Microservices Backend:** Build robust, scalable services including an API Gateway, Wallet Service (Double-Entry Ledger), and AI Fraud Engine.
2. **Build a Cross-Platform Mobile App:** Create a Flutter-based mobile application acting as the primary user interface and mesh networking node.
3. **Integrate Hybrid Mesh Networking:** Implement BLE (for discovery) and Wi-Fi Direct (for data transfer) within the mobile app to support offline P2P transaction forwarding.
4. **Ensure End-to-End Security:** Utilize AES-256-GCM encryption for all transactions, ensuring data integrity and confidentiality across the mesh network.

## 3. System Architecture
### 3.1 Backend Services (Cloud / Online Infrastructure)
- **API Gateway:** Central entry point for all online client requests. Handles routing, rate limiting, and initial authentication.
- **Wallet Service:** Manages the core double-entry ledger. Ensures transactional integrity (ACID compliance) and handles eventual consistency reconciliation when offline transactions are uploaded.
- **AI Fraud Engine:** Analyzes transaction patterns in real-time to detect anomalies and flag potentially fraudulent activities.
- **Database:** PostgreSQL (for relational data like users/wallets) and Redis (for caching and session management). Containerized via Docker (`docker-compose.yml`).

### 3.2 Mobile Application (Offline-First Node)
- **Framework:** Flutter (Dart).
- **Core Modules:**
  - **NetworkService:** Manages BLE discovery, Wi-Fi Direct connections, and the adaptive distance-vector routing protocol.
  - **TransactionService:** Handles local store-and-forward queuing of encrypted offline transactions.
  - **EncryptionService:** Secures payloads using AES-256-GCM before they enter the mesh.
  - **SyncService:** Detects internet connectivity and acts as an uplink, flushing the local offline transaction queue to the API Gateway.

## 4. Phased Implementation Plan

### Phase 1: Foundation & Infrastructure (Weeks 1-2)
- Set up the mono-repo structure (already partially completed).
- Configure `docker-compose.yml` for local development (PostgreSQL, Redis, backend services).
- Initialize the backend microservices (Node.js/Go) and the Flutter mobile app skeleton.
- Implement the baseline CI/CD pipelines.

### Phase 2: Core FinTech Features (Weeks 3-5)
- Develop the **Wallet Service** with strict double-entry accounting principles.
- Implement User Authentication and JWT generation.
- Develop the **AI Fraud Engine** (Python/FastAPI) and integrate it with the Wallet Service.
- Build the basic online functionality in the Flutter mobile app (balance check, online transfers).

### Phase 3: Offline Mesh Integration (GetConnect Methodology) (Weeks 6-9)
- Implement **BLE peer discovery** in the Flutter app using platform channels.
- Implement **Wi-Fi Direct TCP data transfer** for high-bandwidth P2P communication.
- Develop the **Adaptive Routing Protocol** (metric calculation, routing tables, loop prevention).
- Build the **Store-and-Forward** queuing system for offline transactions.
- Implement end-to-end AES-256-GCM encryption for the transaction payloads.

### Phase 4: Synchronization & Reconciliation (Weeks 10-11)
- Develop the protocol for mesh nodes to detect internet access and securely offload queued transactions to the backend.
- Implement conflict resolution and transaction reconciliation logic in the Wallet Service to handle delayed, out-of-order offline transactions.

### Phase 5: Testing, QA, and Optimization (Weeks 12-14)
- **Simulated Offline Testing:** Deploy the app on multiple physical devices to test mesh formation, transaction forwarding, and multi-hop latency.
- **Security Audits:** Review encryption implementation, replay-attack protection, and identity verification.
- **Performance Tuning:** Optimize battery consumption (targeting < 50 mAh/hr idle) and API response times.

## 5. Next Steps
- Finalize the technology stack choices for the backend services.
- Define the exact JSON schema for the offline transaction payloads and the routing table updates.
- Begin implementation of Phase 1 (Database initialization and API Gateway).
