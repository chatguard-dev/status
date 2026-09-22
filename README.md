# Chat Guard uptime

Every five minutes `probe.sh` checks the public endpoints of [Chat Guard](https://chatguard.dev):

- `https://api.chatguard.dev/readyz` (API and its database and cache)
- `https://api.chatguard.dev/openapi/v1.json`
- `https://app.chatguard.dev/sign-in` (dashboard)
- `https://chatguard.dev/` (site)
- the TLS certificates of the three hosts (must have at least 10 days left)

Each target gets three attempts twenty seconds apart. A new outage opens an issue labelled
**incident**, and the failed run e-mails the repository owner; recovery closes the issue with the
duration. Open and past incidents: [issues labelled incident](../../issues?q=label%3Aincident).
