# Chat Guard uptime

The public endpoints of [Chat Guard](https://chatguard.dev) are checked every few minutes by an
external monitor, with GitHub-based probes as a backup; an outage alerts the operator.

This repository is that backup. `probe.sh` runs from GitHub Actions on GitHub's schedule, which is
best effort, so runs can be hours apart. It checks:

- `https://api.chatguard.dev/readyz` (API and its database and cache)
- `https://api.chatguard.dev/openapi/v1.json`
- `https://app.chatguard.dev/sign-in` (dashboard)
- `https://chatguard.dev/` (site) and its `/terms`, `/privacy` and `/dpa` pages
- `https://www.chatguard.dev/` (must redirect to `https://chatguard.dev/`)
- `https://chatguard.dev/discord` (must redirect to our Discord invite)
- the TLS certificates of the four hosts (must have at least 10 days left)

Each target gets three attempts twenty seconds apart. A new outage opens an issue labelled
**incident**, and the failed run e-mails the repository owner; recovery closes the issue with the
duration. Open and past incidents: [issues labelled incident](../../issues?q=label%3Aincident).
