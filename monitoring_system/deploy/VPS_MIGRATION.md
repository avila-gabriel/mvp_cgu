# VPS Migration

Use this when moving the app from one VPS to another, including a domain change.

## What Must Move

Only Postgres needs to be migrated.

Do not copy:
- `caddy-data`
- `caddy-config`
- old `Caddyfile`

Those should be recreated on the new VPS for the new domain.

## Old VPS

1. Pick a dump path:

```bash
BACKUP_FILE=/tmp/monitoring-system.dump
```

2. Dump the database:

```bash
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__OLD_DOMAIN__ task prod:db:dump BACKUP_FILE="$BACKUP_FILE"
```

3. Copy the dump to the new VPS:

```bash
scp "$BACKUP_FILE" __USER__@__NEW_VPS__:/tmp/monitoring-system.dump
```

## New VPS

1. Install the machine from scratch first.
2. Point the new domain to the new VPS.
3. Build the production images:

```bash
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__NEW_DOMAIN__ task prod:build
```

4. Restore the database:

```bash
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__NEW_DOMAIN__ task prod:db:restore BACKUP_FILE=/tmp/monitoring-system.dump
```

5. Bring the stack up:

```bash
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__NEW_DOMAIN__ task prod:up
```

6. Check status:

```bash
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__NEW_DOMAIN__ task prod:status
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__NEW_DOMAIN__ task deploy:status
```

7. If needed, run one compatible deploy on the new VPS to verify blue-green:

```bash
DEPLOY_ROOT=/srv/monitoring-system SITE_ADDRESS=__NEW_DOMAIN__ task deploy:compatible
```

## Cutover

1. Lower DNS TTL before the move if possible.
2. Stop writes on the old VPS before taking the final dump.
3. Take the final dump.
4. Restore it on the new VPS.
5. Start the new VPS.
6. Switch DNS to the new domain/VPS.

## Notes

- `prod:up` will run migrations again. That is expected.
- If the domain changes, Caddy will request fresh certificates on the new VPS.
- If you want a dry run first, use `/srv/monitoring-system-test` instead of `/srv/monitoring-system`.
