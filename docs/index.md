# Horizon5 Documentation

Horizon5 is a portfolio-oriented algorithmic trading framework for MetaTrader 5. These documents describe the framework itself — its architecture, orchestration model, services, and extension surface — not any particular trading strategy or instrument.

## How the documentation is organized

| Section                             | Purpose                                                                          |
| ----------------------------------- | -------------------------------------------------------------------------------- |
| [Getting Started](getting-started/) | Requirements, installation, compilation, and the shape of the project            |
| [How-To Guides](how-to/)            | Task-oriented guides for adding strategies/assets, configuring risk, going live  |
| [Reference](reference/)             | Inputs, services, events, order states, naming rules, integration wire contracts |
| [Explanation](explanation/)         | Architecture, portfolio model, order lifecycle, service model, design rationale  |

## Starting points

- New to the framework? Start with [Getting Started](getting-started/index.md).
- Want to understand the design? Read [Explanation > Service Architecture](explanation/service-architecture.md) and [Explanation > Portfolio Approach](explanation/portfolio-approach.md).
- Building on top of it? Jump to [How-To > Add a Strategy](how-to/add-strategy.md).

## Ecosystem

Horizon5 can run fully standalone. For full operational capacity — remote order management, centralized monitoring, and a live dashboard — there is a private ecosystem (Gateway, Monitor, War Room). The EA ships with integration points for those services, but the services themselves are not part of this repository. Reach out via [GitHub](https://github.com/pedrocarvajal) if you want access.
