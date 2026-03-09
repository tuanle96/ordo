# Contributing to Ordo

Thank you for your interest in contributing to Ordo! 🎉

## License

By contributing to Ordo, you agree that your contributions will be licensed under the [GNU Affero General Public License v3.0](LICENSE).

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/tuanle96/ordo/issues)
2. Create a new issue with a clear title and description
3. Include steps to reproduce, expected behavior, and actual behavior
4. Add relevant logs, screenshots, or screen recordings

### Suggesting Features

1. Open a [GitHub Discussion](https://github.com/tuanle96/ordo/discussions) or Issue
2. Describe the use case and expected behavior
3. If possible, reference how the feature works in Odoo web

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes following the coding standards below
4. Write/update tests as needed
5. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat: add barcode scanner`
   - `fix: resolve login crash on iOS 17`
   - `docs: update API reference`
6. Push and open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/ordo.git
cd ordo

# Install dependencies
npm install

# Copy environment config
cp backend/.env.example backend/.env

# Start backend (dev mode)
npm run dev:backend

# iOS — open in Xcode
open ios/Ordo.xcodeproj
```

## Coding Standards

### Backend (TypeScript / NestJS)

- Follow existing code style (enforced by ESLint)
- Use `class-validator` for DTO validation
- Write tests for new endpoints (Jest + Supertest)
- New Odoo version? → Add adapter in `backend/src/odoo/adapters/`

### iOS (Swift / SwiftUI)

- Target iOS 17+
- Use `@Observable` for state management
- Follow MVVM pattern with `@MainActor` isolation
- New field type? → Add widget in `ios/Ordo/features/record-detail/`

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix      | Usage                 |
| ----------- | --------------------- |
| `feat:`     | New feature           |
| `fix:`      | Bug fix               |
| `docs:`     | Documentation         |
| `refactor:` | Code restructuring    |
| `test:`     | Adding/updating tests |
| `chore:`    | Maintenance tasks     |

## Community

- Be respectful and constructive
- Help others in issues and discussions
- Share your Ordo use cases and feedback

Thank you for helping make Odoo Community mobile-accessible! 🚀
