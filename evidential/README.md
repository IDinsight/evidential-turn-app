# test_app

A Turn.io Lua app.

## Quick Start

```bash
# Run tests
make test

# Watch mode (auto-run tests on file changes)
make watch

# Build ZIP for deployment
make build
```

## Using turn-app command

If you have the `turn-app` alias set up:

```bash
turn-app test       # Run tests
turn-app watch      # Watch mode
turn-app build      # Build ZIP
```

## Project Structure

```
test_app/
├── test_app.lua              # Main app code
├── spec/
│   └── test_app_spec.lua     # Tests
├── assets/
│   ├── manifest.json            # App metadata (required)
│   ├── README.md                # App documentation (for UI)
│   ├── journeys/                # Journey templates
│   └── liquid/                  # Liquid templates
├── lib/                         # Additional Lua modules
├── Makefile                     # Build commands
├── TESTING.md                   # Testing guide and API reference
├── AGENTS.md                    # AI agent development guide
└── README.md                    # This file
```

## Testing

Tests use the [lester](https://github.com/bjornbytes/lester) testing framework (Busted-compatible API).

See `spec/test_app_spec.lua` for examples.

**For comprehensive testing documentation**, including testing API reference, common patterns, and debugging tips, see [TESTING.md](TESTING.md).

## Building

The build process creates a ZIP file with:
- Main Lua file (`test_app.lua`)
- `assets/` directory (including manifest.json and README.md for UI display)
- `lib/` directory (if present)

Excludes:
- Test files (`spec/`)
- This README.md (developer documentation)
- TESTING.md (developer documentation)
- AGENTS.md (AI agent guidance)
- Makefile

## App Documentation

When users view your app in the Turn.io UI, they see `assets/README.md`. Edit that file to provide user-facing documentation, configuration instructions, and usage examples.

## AI-Assisted Development

If you're using AI coding assistants (like Claude, Cursor, GitHub Copilot, etc.), check out [AGENTS.md](AGENTS.md) for comprehensive guidance tailored for AI agents. This file includes:

- Turn.io API patterns and conventions
- Common pitfalls and how to avoid them
- Testing requirements and patterns
- Security considerations
- Workflow guidance for feature implementation

Many modern AI coding tools automatically read `AGENTS.md` files for context.

## Learn More

- [Turn.io Apps Documentation](https://whatsapp.turn.io/docs)
- [Lester Testing Framework](https://github.com/bjornbytes/lester)
- [Lua 5.3 Reference](https://www.lua.org/manual/5.3/)
