# Deploy Runbook

## Required env vars for local production testing

Use these when testing the production workflow locally:

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test"
SITE_ADDRESS=local.test
```

## VPS dry run before real prod

Do this on the Ubuntu VPS before using the real production deploy root.

1. Pick a real test subdomain and point it to the VPS.
2. Make sure ports `80` and `443` are free on the VPS.
3. Use `DEPLOY_ROOT=/srv/monitoring-system-test`.
4. Start from a clean test state:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test docker compose -f deploy/compose.yaml down -v --remove-orphans && docker run --rm -v "/srv/monitoring-system-test:/target" alpine sh -c 'rm -rf /target/*' && docker rmi monitoring-system-app:blue monitoring-system-app:green 2>/dev/null || true && docker image prune -f
```

5. Bring the test production stack up:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test SITE_ADDRESS=__TEST_SUBDOMAIN__ task prod:up
```

6. Check status:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test SITE_ADDRESS=__TEST_SUBDOMAIN__ task prod:status
```

7. Test blue-green deployment:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test SITE_ADDRESS=__TEST_SUBDOMAIN__ task deploy:compatible
```

8. Check blue-green status:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test SITE_ADDRESS=__TEST_SUBDOMAIN__ task deploy:status
```

9. Shut the test stack down:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test SITE_ADDRESS=__TEST_SUBDOMAIN__ task prod:down
```

If all steps above pass, the deployment flow is working on the VPS without touching `/srv/monitoring-system`.

## Local production-like testing

### Clean everything and start fresh

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" docker compose -f deploy/compose.yaml down -v --remove-orphans && docker run --rm -v "$HOME/.local/share/monitoring-system-test:/target" alpine sh -c 'rm -rf /target/*' && docker rmi monitoring-system-app:blue monitoring-system-app:green 2>/dev/null || true && docker image prune -f
```

### Bring production stack up locally

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task prod:up
```

### Check status

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task prod:status
```

### Follow logs

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task prod:logs
```

### Test blue-green deployment

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task deploy:compatible
```

### Check blue-green status

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task deploy:status
```

### Shut everything down

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task prod:down
```

## DEPLOY_ROOT

All production-like local testing should use:

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test"
```

## Only Postgres is up

Run:

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task prod:status
```

Then inspect:

```bash
DEPLOY_ROOT="$HOME/.local/share/monitoring-system-test" SITE_ADDRESS=local.test task prod:logs
```
