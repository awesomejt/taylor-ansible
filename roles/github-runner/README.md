# github-runner

Installs and registers a GitHub Actions self-hosted runner as a systemd service.

## What it does

- Creates a dedicated `gh-runner` service user and adds it to the `docker` group
- Downloads and extracts the runner binary (version-pinned, upgrades cleanly)
- Obtains a fresh registration token from the GitHub API using a PAT
- Registers the runner with `config.sh --unattended --replace`
- Installs and starts a `github-runner.service` systemd unit

Registration only runs when the `.runner` credential file is absent. Subsequent
playbook runs are fully idempotent unless `gh_runner_force_reconfigure: true` is set.

## Prerequisites

**GitHub PAT** — create a fine-grained token (or classic PAT) with:

| Token type | Required permission |
|---|---|
| Fine-grained (recommended) | Organization → Self-hosted runners: Read and write |
| Classic | `admin:org` (includes `manage_runners:org`) |

Store the PAT in Vault at `infra/github-runner/pat` and add a lookup to
`vars/vault-secrets.yaml`. See `vars/common/example-secrets.yaml` for the
variable name and generation instructions.

**Docker** — the `docker` role must run before this role so the `docker` group
exists and the runner user can be added to it.

## Key variables

| Variable | Default | Description |
|---|---|---|
| `gh_runner_org` | `""` | GitHub org name (required) |
| `gh_runner_scope` | `"org"` | `"org"` or `"repo"` |
| `gh_runner_repo` | `""` | Required when `scope == "repo"` |
| `gh_runner_name` | `inventory_hostname` | Runner name shown in GitHub UI |
| `gh_runner_labels` | `"self-hosted,linux,docker"` | Comma-separated labels |
| `gh_runner_version` | `"2.322.0"` | Runner binary version |
| `gh_runner_force_reconfigure` | `false` | Re-register even if `.runner` exists |
| `gh_runner_pat` | `vault_gh_runner_pat` | GitHub PAT for registration API calls |

## Upgrading the runner binary

Update `gh_runner_version` in defaults or the playbook vars. On the next run,
the role stops the service, extracts the new binary, and restarts. The existing
`.runner` credentials are preserved — no re-registration needed.

## Removing a runner

```bash
# On the runner host:
sudo systemctl stop github-runner
cd /opt/github-runner
sudo -u gh-runner ./config.sh remove --token <removal-token>
sudo rm /etc/systemd/system/github-runner.service
sudo systemctl daemon-reload
```

Get a removal token from: `POST /orgs/{org}/actions/runners/remove-token`
