#!/usr/bin/env bash
# Probes the public Chat Guard endpoints and the TLS certificates behind them. Every failing target
# is written to failures.txt as "name | detail"; the script itself always exits 0 so the workflow can
# decide what to do with the result.
set -u
FAILURES=failures.txt
: > "$FAILURES"

# name | url | expected status | text that must appear in the body, or for a redirect the exact
# address it must point to (empty = any). Redirects are not followed.
TARGETS=(
  "api readiness|https://api.chatguard.dev/readyz|200|"
  "api contract|https://api.chatguard.dev/openapi/v1.json|200|openapi"
  "dashboard|https://app.chatguard.dev/sign-in|200|Chat Guard"
  "landing page|https://chatguard.dev/|200|Chat Guard"
  "www redirect|https://www.chatguard.dev/|308|https://chatguard.dev/"
  # The invite the site's /discord link sends people to; change it here when the invite changes.
  "discord link|https://chatguard.dev/discord|307|https://discord.gg/udtGVvXsRE"
  "terms|https://chatguard.dev/terms|200|Terms of service"
  "privacy notes|https://chatguard.dev/privacy|200|Privacy notes"
  "dpa|https://chatguard.dev/dpa|200|Data processing agreement"
)
ATTEMPTS=3
PAUSE=20

probe() {
  local url=$1 expected=$2 needle=$3 body code location
  body=$(mktemp)
  # curl prints 000 as the status when it gets no answer at all.
  read -r code location <<< "$(curl -sS -o "$body" -w '%{http_code} %{redirect_url}' --max-time 15 -A "chatguard-uptime/1" "$url" 2>/dev/null)"
  code=${code:-000}
  if [[ "$code" != "$expected" ]]; then
    rm -f "$body"
    echo "HTTP $code (expected $expected)"
    return 1
  fi
  if [[ "$code" == 3* ]]; then
    rm -f "$body"
    if [[ -n "$needle" && "$location" != "$needle" ]]; then
      echo "HTTP $code to ${location:-no address} (expected $needle)"
      return 1
    fi
    return 0
  fi
  if [[ -n "$needle" ]] && ! grep -q -- "$needle" "$body"; then
    rm -f "$body"
    echo "HTTP $code but the body does not contain \"$needle\""
    return 1
  fi
  rm -f "$body"
  return 0
}

for target in "${TARGETS[@]}"; do
  IFS='|' read -r name url expected needle <<< "$target"
  detail=""
  ok=0
  for attempt in $(seq 1 "$ATTEMPTS"); do
    if detail=$(probe "$url" "$expected" "$needle"); then
      ok=1
      break
    fi
    [[ "$attempt" -lt "$ATTEMPTS" ]] && sleep "$PAUSE"
  done
  if [[ "$ok" -eq 1 ]]; then
    echo "ok    $name"
  else
    echo "DOWN  $name: $detail ($ATTEMPTS attempts)"
    echo "$name | $url | $detail after $ATTEMPTS attempts" >> "$FAILURES"
  fi
done

# TLS: fail when a certificate has fewer than 10 days left (Fly renews them well before that).
for host in api.chatguard.dev app.chatguard.dev chatguard.dev www.chatguard.dev; do
  end=$(echo | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [[ -z "$end" ]]; then
    echo "DOWN  tls $host: no certificate presented"
    echo "tls $host | https://$host | no certificate presented" >> "$FAILURES"
    continue
  fi
  # GNU date on the runner; BSD date when run from a Mac.
  end_epoch=$(date -u -d "$end" +%s 2>/dev/null || date -j -u -f "%b %e %T %Y %Z" "$end" +%s)
  days=$(( (end_epoch - $(date -u +%s)) / 86400 ))
  if [[ "$days" -lt 10 ]]; then
    echo "DOWN  tls $host: certificate expires in $days days ($end)"
    echo "tls $host | https://$host | certificate expires in $days days ($end)" >> "$FAILURES"
  else
    echo "ok    tls $host ($days days left)"
  fi
done
