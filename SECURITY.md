# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

We take the security of Ordo seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**⚠️ Please do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please report security issues by emailing **contact@ordo.vn** with the following information:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Affected component** (backend, iOS app, authentication, etc.)
4. **Potential impact** of the vulnerability
5. **Suggested fix** (if you have one)

### What to Expect

- **Acknowledgment** within 48 hours of your report
- **Assessment** of the vulnerability within 1 week
- **Fix timeline** communicated based on severity:
  - **Critical** (auth bypass, data exposure): Patch within 72 hours
  - **High** (privilege escalation, injection): Patch within 1 week
  - **Medium** (information disclosure): Patch within 2 weeks
  - **Low** (minor issues): Included in next release

### Security Best Practices for Deployers

- Always use strong, unique values for `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET`
- Keep Redis protected behind a firewall or use password authentication
- Use HTTPS in production (never expose the API over plain HTTP)
- Regularly update dependencies (`npm audit`)
- Restrict CORS origins via `CORS_ALLOWED_ORIGINS` in production
- Never commit `.env` files to version control

## Acknowledgments

We appreciate the security research community's efforts in helping keep Ordo and its users safe. Contributors who responsibly disclose vulnerabilities will be acknowledged in our release notes (with permission).
