# CLAUDE.md

# Rules

- On every `.mq5` file modification, bump `#property version` using the `MAJOR.MINORPATCH` format (e.g. `1.00`, `1.01`, `1.10`, `1.11`): MAJOR for breaking changes, MINOR (tens digit) for new functionality, PATCH (ones digit) for fixes or non-functional changes. This does not apply to `.mqh` files. Update the version before committing/pushing changes.
