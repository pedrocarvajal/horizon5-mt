---
name: Bug report
about: Report a bug to help us improve Horizon Connect
title: "[BUG] "
labels: "bug"
assignees: ""
---

## Bug Description

A clear and concise description of the bug.

## Affected Component

Please select the component(s) affected:

- [ ] Backtest Service
- [ ] Production Service
- [ ] Gateway (MetaAPI/other)
- [ ] Strategy Service
- [ ] Analytic Service
- [ ] Order Management
- [ ] Candle/Tick Service
- [ ] Portfolio Service
- [ ] Indicators
- [ ] Other

## Steps to Reproduce

Provide detailed steps to reproduce the behavior:

```python
# Minimal reproducible code example
```

1. Configuration used (portfolio, strategy, gateway settings)
2. Commands executed
3. Specific actions that trigger the bug

## Expected Behavior

What did you expect to happen?

## Actual Behavior

What actually happened? Include:

- Error messages
- Stack traces
- Log output (from `logs/` directory)
- Unexpected results

## Environment

- **OS**: [e.g. macOS 13.0, Ubuntu 22.04, Windows 11]
- **Python Version**: [e.g. 3.11.5]
- **Horizon Connect Version**: [e.g. 0.1.0]
- **Gateway**: [e.g. MetaAPI/MetaTrader]
- **Dependencies**: Run `uv pip list` and paste relevant versions

## Logs

Please attach relevant log files from the `logs/` directory:

- `backtest.log`
- `gateway-metaapi.log`
- Other relevant logs

## Additional Context

- Does this occur consistently or intermittently?
- Did this work in a previous version?
- Any recent changes to configuration or environment?
- Related issues:

## Potential Impact

- [ ] Data loss or corruption
- [ ] Trading execution affected
- [ ] Performance degradation
- [ ] Documentation issue
- [ ] Minor inconvenience
