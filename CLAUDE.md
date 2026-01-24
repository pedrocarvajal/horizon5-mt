# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Horizon is an algorithmic trading system for MetaTrader 5, built in MQL5.
It implements a portfolio-based approach where multiple trading strategies run simultaneously with intelligent order management, risk controls, and performance statistics.

## Context-First Development

Before implementing, modifying, or creating any code, you MUST gather complete context of the existing architecture:

- **Understand the class hierarchy flow**: Trace the inheritance chain and dependencies to understand available methods, properties, and helpers.

- **Check existing utilities and helpers**: Search for existing implementations, and related directories before creating new functionality.

- **Avoid duplication**: Never recreate functionality that already exists. Use existing methods, helpers, and patterns.

- **Follow established patterns**: New code must align with the architectural conventions already present in the codebase.

This prevents redundant implementations and ensures consistency across the project.
