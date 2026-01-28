## Description

Provide a clear and concise description of what this PR does.

Fixes #(issue)

## Type of Change

Please select the type of change:

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Refactoring (code restructuring without changing behavior)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Test coverage improvement
- [ ] Dependency update

## Component(s) Affected

Select all that apply:

- [ ] Backtest Service
- [ ] Production Service
- [ ] Gateway Service (MetaAPI/other)
- [ ] Strategy Service
- [ ] Analytic Service
- [ ] Portfolio Service
- [ ] Candle/Tick Service
- [ ] Order Management
- [ ] Indicators
- [ ] Models
- [ ] Helpers/Utilities
- [ ] Tests
- [ ] Documentation
- [ ] Configuration

## Changes Made

Summarize the key changes in bullet points:

-
-
-

## Testing

### Test Coverage

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] E2E tests added/updated
- [ ] Manual testing completed
- [ ] All tests pass locally

### How to Test

Describe the steps to test these changes:

```python
# Example code to test the changes
```

1.
2.
3.

## Performance Impact

- [ ] No performance impact
- [ ] Performance improved
- [ ] Performance may be affected (explain below)

**Details:**

## Breaking Changes

- [ ] This PR introduces breaking changes

**If yes, describe the breaking changes and migration path:**

## Documentation

- [ ] Code is self-documenting with clear variable names
- [ ] Docstrings added/updated for public APIs
- [ ] Type hints added to all functions
- [ ] README.md updated (if applicable)
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Comments added for complex logic

## Dependencies

- [ ] No new dependencies added
- [ ] New dependencies added (list below)

**New dependencies:**

```toml
# List new dependencies from pyproject.toml
```

## Checklist

Before submitting, ensure you have:

- [ ] Read and followed the [CONTRIBUTING.md](../CONTRIBUTING.md) guidelines
- [ ] Code follows project style guidelines (Ruff + MyPy)
- [ ] Ran `uv run ruff format .` to format code
- [ ] Ran `uv run ruff check .` and fixed all issues
- [ ] Ran `uv run mypy .` and fixed all type errors
- [ ] All tests pass (`make run-tests`)
- [ ] Commits are clean and follow conventional commit format
- [ ] Branch is up to date with main/target branch
- [ ] Self-reviewed the code for potential issues
- [ ] Added tests that prove the fix/feature works
- [ ] Verified no sensitive data (API keys, secrets) in code

## Screenshots/Logs (if applicable)

Add screenshots, log output, or performance metrics if relevant:

```
# Paste relevant logs or output
```

## Additional Context

Add any other context about the PR here:

- Related PRs:
- References (docs, papers, discussions):
- Migration notes:
- Known limitations:

## Reviewer Notes

Specific areas you'd like reviewers to focus on:

-
-
- ***

  **License Acknowledgment:**
  By submitting this PR, I confirm that my contributions are licensed under the PolyForm Noncommercial License 1.0.0 and comply with the project's license requirements.
