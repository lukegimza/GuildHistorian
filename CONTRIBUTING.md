# Contributing to Guild Historian

Thanks for your interest in contributing! Here's how to get started.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a feature branch (`git checkout -b feature/your-feature`)
4. Make your changes
5. Test in-game
6. Commit and push
7. Open a Pull Request

## Code Guidelines

### Style

- **Indentation:** 4 spaces (no tabs)
- **Line length:** 120 characters max
- **Encoding:** UTF-8 with LF line endings
- **Namespace:** Always use `local GH, ns = ...` at the top of every file. Never create global variables.

### Lua

- Follow the existing code patterns
- Use `ns.` namespace for sharing between files
- Register events through AceEvent mixins
- Use the Database module for data persistence
- Use `Utils.safecall()` for error-safe function invocation

### Localization

- All user-facing strings go in `Locales/enUS.lua` first
- Reference strings via `ns.L["KEY"]`
- Translation contributions go in the appropriate locale file

### Testing

- Test your changes in-game on WoW Retail
- Verify luacheck passes: run luacheck locally or check the CI status
- Test with `/gh debug` enabled to verify event flow

## Pull Request Process

1. Ensure your code passes luacheck (the CI will verify this)
2. Update the CHANGELOG if adding features or fixing bugs
3. Describe your changes clearly in the PR description
4. Link any related issues

## Reporting Bugs

Use the [Bug Report template](https://github.com/lukegimza/GuildHistorian/issues/new?template=bug_report.md) and include:
- Steps to reproduce
- Expected vs actual behavior
- WoW version and addon version
- Any error messages from BugSack/BugGrabber

## Feature Requests

Use the [Feature Request template](https://github.com/lukegimza/GuildHistorian/issues/new?template=feature_request.md).

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
