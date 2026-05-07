# Vault Backup and Rollback

This workflow is designed to protect vaulted secrets before and during refactors.

Scope:
- Real secret changes happen on host 192.168.50.11 in ~/ansible
- Local workspace keeps example secrets as placeholders only
- Backups copy encrypted files as-is (no decryption required)

## Files

- scripts/vault-secrets-backup.sh
- scripts/vault-secrets-rollback.sh

## 1) Host setup

Run these commands on 192.168.50.11:

```bash
cd ~/ansible
chmod 700 scripts/vault-secrets-backup.sh scripts/vault-secrets-rollback.sh
mkdir -p ~/.ansible-vault-backups
chmod 700 ~/.ansible-vault-backups
```

## 2) Create a backup snapshot

```bash
cd ~/ansible
scripts/vault-secrets-backup.sh ~/ansible ~/.ansible-vault-backups 45
```

Arguments:
- arg1: repo dir (default: ~/ansible)
- arg2: backup dir (default: ~/.ansible-vault-backups)
- arg3: retention days for tar backups (default: 45)

Output:
- timestamped tar snapshot in ~/.ansible-vault-backups
- includes files.list and sha256sums.txt for integrity verification

## 3) Restore (rollback) a snapshot

Rollback by timestamp:

```bash
cd ~/ansible
scripts/vault-secrets-rollback.sh 20260507-204500 ~/ansible ~/.ansible-vault-backups
```

Rollback by explicit tar path:

```bash
cd ~/ansible
scripts/vault-secrets-rollback.sh ~/.ansible-vault-backups/20260507-204500.tar.gz
```

Safety behavior:
- verifies snapshot checksums before restore
- creates a fresh pre-restore backup snapshot before overwriting files

## 4) Validation after rollback

Run syntax checks before applying any playbook:

```bash
cd ~/ansible
ansible-playbook -i inventory.ini hermes.yaml --syntax-check --ask-vault-pass
```

## 5) Cron backup schedule

Example (every 6 hours):

```bash
crontab -e
```

```cron
0 */6 * * * /home/jason/ansible/scripts/vault-secrets-backup.sh /home/jason/ansible /home/jason/.ansible-vault-backups 45 >> /home/jason/.ansible-vault-backups/backup.log 2>&1
```

## 6) Guardrails

- Do not store real secrets in example-secrets files.
- Keep backup directory permissions restricted to the owner.
- Always take a fresh backup immediately before refactor or secret edits.
