# Contributing to Horizon Connect

Thank you for your interest in contributing to Horizon Connect! This document provides guidelines and instructions for contributing to this quantitative trading framework.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [License Considerations](#license-considerations)

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to <hello@horizon5.tech>.

## Getting Started

### Prerequisites

- **Python 3.11+** (required)
- **uv** package manager (recommended) or pip
- Git for version control
- Basic understanding of quantitative trading concepts
- Familiarity with async Python programming

### First Contribution

Looking for a way to contribute? Check out:

- Issues labeled `good first issue`
- Issues labeled `help wanted`
- Documentation improvements
- Test coverage enhancements

## Development Setup

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/horizon5-connect.git
cd horizon5-connect
```

### 2. Install Dependencies

Using `uv` (recommended):

```bash
uv sync
```

Using `pip`:

```bash
pip install -r requirements.txt
```

### 3. Environment Configuration

Create a `.env` file in the project root:

```bash
cp .env.example .env
```

Configure your environment variables:

- `METAAPI_AUTH_TOKEN` - Your MetaAPI authentication token
- `METAAPI_ACCOUNT_ID` - Your MetaAPI account ID
- Other gateway credentials as needed

### 4. Verify Setup

Run the test suite:

```bash
make run-tests
```

## Project Structure

```text
horizon5-connect/
├── assets/          # Asset configurations (e.g., xauusd)
├── configs/         # System-wide configurations
├── enums/           # Enumerations (order types, status, etc.)
├── helpers/         # Generic utility functions
├── indicators/      # Technical indicators
├── interfaces/      # Abstract base classes and protocols
├── models/          # Data models (Order, Trade, Snapshot, etc.)
├── portfolios/      # Portfolio configurations
├── services/        # Core services (gateway, strategy, backtest, etc.)
├── strategies/      # Trading strategy implementations
├── tests/           # Test suite (unit, integration, e2e)
└── logs/            # Application logs
```

### Key Services

- **GatewayService**: Exchange/broker connectivity
- **StrategyService**: Trading strategy execution
- **BacktestService**: Historical strategy testing
- **ProductionService**: Live trading execution
- **AnalyticService**: Performance metrics and reporting
- **PortfolioService**: Multi-asset portfolio management

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

Use conventional branch naming:

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions or modifications

### 2. Make Your Changes

- Write clean, readable code
- Follow the project's coding standards
- Add tests for new functionality
- Update documentation as needed
- Keep commits atomic and focused

### 3. Run Quality Checks

```bash
# Format code
uv run ruff format .

# Lint code
uv run ruff check .

# Type checking
uv run mypy .

# Run tests
make run-tests
```

### 4. Commit Your Changes

Use conventional commit messages:

```text
type(scope): subject

body (optional)

footer (optional)
```

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance tasks

Example:

```bash
git commit -m "feat(gateway): add MetaTrader 5 support"
```

### 5. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Create a pull request on GitHub with:

- Clear title following conventional commits
- Detailed description of changes
- Reference to related issues
- Screenshots/logs if applicable

## Coding Standards

### Python Style Guide

This project follows strict Python standards enforced by Ruff and MyPy:

#### Type Annotations

**Required** for all functions and methods:

```python
def calculate_sharpe_ratio(returns: list[float], risk_free_rate: float = 0.0) -> float:
    """Calculate Sharpe ratio from returns."""
    pass
```

#### Code Formatting

- Line length: 120 characters
- Use double quotes for strings
- Follow PEP 8 conventions
- Use type hints consistently

#### Async/Await

Prefer async patterns for I/O operations:

```python
async def fetch_candles(self, symbol: str) -> list[Candle]:
    """Fetch candles asynchronously."""
    async with self.session.get(url) as response:
        return await response.json()
```

#### Error Handling

```python
from services.logging import LoggingService

logger = LoggingService("my-component")

try:
    result = await risky_operation()
except SpecificException as e:
    logger.error(f"Operation failed: {e}")
    raise
```

#### Documentation

Use docstrings for public APIs:

```python
def get_portfolio_by_path(path: str) -> PortfolioInterface:
    """
    Load portfolio configuration from a Python file.

    Args:
        path: Relative or absolute path to portfolio file

    Returns:
        Portfolio instance implementing PortfolioInterface

    Raises:
        FileNotFoundError: If portfolio file doesn't exist
        ValidationError: If portfolio configuration is invalid
    """
```

### Service Development Guidelines

When creating new services:

1. **Extend proper interface** from `interfaces/`
2. **Use dependency injection** for service dependencies
3. **Implement proper logging** using `LoggingService`
4. **Handle errors gracefully** with specific exceptions
5. **Write comprehensive tests** (unit + integration)

### Strategy Development Guidelines

When creating trading strategies:

1. **Inherit from `StrategyService`**
2. **Implement required methods**: `on_tick()`, `on_candle()`, etc.
3. **Use indicators properly** from `indicators/`
4. **Implement risk management** (position sizing, stop losses)
5. **Document strategy logic** clearly
6. **Backtest thoroughly** before production use

Example:

```python
from services.strategy import StrategyService

class MyStrategy(StrategyService):
    """Custom trading strategy."""

    def __init__(self) -> None:
        super().__init__()
        self.logger = LoggingService("my-strategy")

    async def on_tick(self, tick: Tick) -> None:
        """Process incoming tick data."""
        pass
```

## Testing

### Test Structure

- `tests/unit/` - Unit tests for isolated components
- `tests/integration/` - Integration tests for service interactions
- `tests/e2e/` - End-to-end tests for complete workflows

### Writing Tests

Use pytest conventions:

```python
import pytest
from services.analytic import AnalyticService

def test_sharpe_ratio_calculation() -> None:
    """Test Sharpe ratio calculation."""
    service = AnalyticService()
    returns = [0.01, 0.02, -0.01, 0.03]

    sharpe = service.calculate_sharpe_ratio(returns)

    assert isinstance(sharpe, float)
    assert sharpe > 0

@pytest.mark.asyncio
async def test_gateway_connection() -> None:
    """Test async gateway connection."""
    gateway = GatewayService()

    result = await gateway.connect()

    assert result is True
```

### Running Tests

```bash
# All tests
make run-tests

# Unit tests only
make run-tests-unit

# Integration tests only
make run-tests-integration

# E2E tests only
make run-tests-e2e

# With coverage
uv run python -m pytest --cov=services --cov-report=html
```

### Test Coverage

- Aim for **80%+ coverage** on new code
- Focus on critical paths (order execution, risk management)
- Mock external dependencies (exchanges, databases)
- Test edge cases and error conditions

## Submitting Changes

### Pull Request Guidelines

1. **Title**: Use conventional commit format
   - `feat: Add support for stop-loss orders`
   - `fix: Correct Sharpe ratio calculation`
   - `docs: Update strategy development guide`

2. **Description**: Include:
   - What changes were made
   - Why these changes were necessary
   - How to test the changes
   - Any breaking changes
   - Related issue numbers (#123)

3. **Checklist**:
   - [ ] Code follows project style guidelines
   - [ ] Tests added/updated and passing
   - [ ] Documentation updated (if applicable)
   - [ ] Type hints added to all functions
   - [ ] Linter and type checker pass
   - [ ] Commits are clean and atomic
   - [ ] PR has descriptive title and description

### Review Process

1. Automated checks must pass (linting, type checking, tests)
2. At least one maintainer review required
3. Address review comments promptly
4. Maintainers may request changes or additional tests
5. Once approved, maintainers will merge

## License Considerations

### PolyForm Noncommercial License

This project is licensed under the **PolyForm Noncommercial License 1.0.0**. Key points:

- ✅ **Permitted**: Personal use, research, education, non-profit organizations
- ❌ **Not Permitted**: Commercial use, monetization, business operations
- ✅ **You Can**: Modify, distribute, and create derivative works
- ⚠️ **You Must**: Include license notice, maintain noncommercial terms

### Contributing Your Code

By submitting a pull request, you agree that:

1. Your contributions will be licensed under the same PolyForm Noncommercial License
2. You have the right to submit the code under this license
3. Your contributions are your original work or properly attributed

### Third-Party Dependencies

When adding new dependencies:

- Ensure they have compatible licenses (MIT, BSD, Apache 2.0, etc.)
- Avoid GPL-licensed dependencies (licensing conflicts)
- Document new dependencies in `pyproject.toml`
- Update requirements if necessary

## Questions and Support

### Getting Help

- **Issues**: Open an issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Email**: Contact <hello@horizon5.tech> for private inquiries

### Resources

- [Project Roadmap](README.md#roadmap)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [License](LICENSE.md)
- [Security Policy](SECURITY.md)

---

Thank you for contributing to Horizon Connect! Your efforts help build a robust quantitative trading framework for the community.
