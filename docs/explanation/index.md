# Explanation

Conceptual documentation for the Horizon5 Expert Advisor architecture.

- [Service Architecture](service-architecture.md) -- How the EA offloads blocking I/O to separate service scripts via a DLL-based message bus.
- [Portfolio Approach](portfolio-approach.md) -- Hierarchical asset/strategy model, equal-weight allocation, and deterministic identifiers.
- [Order Lifecycle](order-lifecycle.md) -- Full order flow from signal generation through execution, closure, persistence, and recovery.
- [Observability](observability.md) -- Monitoring, remote order management, deterministic UUIDs, and reporting.
- [Design Decisions](design-decisions.md) -- Rationale behind key architectural and operational choices.
- [Event System](event-system.md) -- Gateway event routing and remote order management.
