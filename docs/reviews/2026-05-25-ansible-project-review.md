# Ansible Project Review - 2026-05-25

## Scope

Reviewed the Ansible repository for approach, structure, code quality, homelab operability, and the recent migration from Ansible Vault toward HashiCorp Vault. This was a static review plus safe local validation only. No playbooks were applied, no files were synced to the Ansible host, and no Vault secrets were viewed or changed.

## High-Level Assessment

The repository has a solid homelab shape: dedicated roles per service, an inventory that clearly reflects the Proxmox VM layout, useful role READMEs, `MEMORY.md` and `TODO.md` discipline, and a sensible separation between Vault installation and Vault post-init configuration. The biggest risks are not in the basic Ansible mechanics. They are in the transition state between "secrets live in encrypted files on the Ansible host" and "services read secrets from HashiCorp Vault".

Right now the secret model is split across Ansible Vault, HashiCorp Vault, SOPS/GitOps, local ignored files, and generated remote files. That can work in a homelab, but the repo needs clearer boundaries and guardrails so a routine sync, lint run, or service apply cannot delete secrets, leak secrets into logs, or silently fall back to placeholder credentials.

## Strengths

- The role-per-service layout is easy to navigate and matches the operational model: `vault`, `vault-configure`, `step-ca`, `technitium-dns`, `k3s-*`, and the Docker Compose services are separated cleanly.
- `vault.yaml`, `vault-configure.yaml`, and `vault-populate.yaml` express different lifecycle phases instead of mixing install, bootstrap, and secret import in one playbook.
- `vars/common/example-secrets.yaml` is sanitized, and no plaintext `vars/*/secrets.yaml` files are tracked.
- Many destructive or secret-bearing API tasks already use `no_log`, especially Harbor API operations and some private-key copy tasks.
- `sync-to-ansible.sh` centralizes host upload behavior, which is the right pattern for this project.
- The repo has useful operational memory in `MEMORY.md` and explicit task history in `TODO.md`, which lowers future-agent context loss.

## Findings

### 1. Critical: `sync-to-ansible.sh --delete` can remove remote-only secrets

`sync-to-ansible.sh` excludes `.git`, temp files, and swap files, but it does not protect `vars/**/secrets.yaml` when the local checkout intentionally does not contain those files. With `--delete`, rsync can delete the real encrypted secret files on `192.168.50.11:~/ansible` because they are absent locally. The script advertises `--delete` in its usage examples.

References:
- `sync-to-ansible.sh:7`
- `sync-to-ansible.sh:153`
- `sync-to-ansible.sh:156`
- `sync-to-ansible.sh:160`
- `sync-to-ansible.sh:163`

Recommendation: add explicit excludes/protect filters for `vars/**/secrets.yaml`, `*.vault`, `.env`, `.ansible/`, `.codex/`, `.agents/`, and other local-only state. Consider making `--delete` refuse to run unless a protection list is active.

### 2. High: the sync script uploads ignored local state

The repo ignores `.env`, `.ansible/`, and `temp/`, but the sync script only excludes `.git`, `.DS_Store`, `*.swp`, and `temp/`. That means `.env`, `.ansible/`, `.codex/`, and `.agents/` can be uploaded to the Ansible host even though they are not part of the tracked project.

References:
- `.gitignore:1`
- `.gitignore:9`
- `sync-to-ansible.sh:153`
- `sync-to-ansible.sh:160`
- `sync-to-ansible.sh:177`
- `sync-to-ansible.sh:183`

Recommendation: make the sync exclude list mirror the local ignore policy and add a dry-run check that warns about untracked dot directories being transferred.

### 3. High: runtime Vault lookups use the broad admin token

`vars/vault-secrets.yaml` sources every HashiCorp Vault secret through `vault_admin_token`, which is stored in `vars/common/secrets.yaml`. That keeps all runtime playbooks dependent on a long-lived admin token with broad read/write/delete/list permissions.

References:
- `vars/vault-secrets.yaml:5`
- `vars/vault-secrets.yaml:7`
- `vars/vault-secrets.yaml:17`
- `vars/vault-secrets.yaml:27`
- `vars/vault-secrets.yaml:53`
- `vars/vault-secrets.yaml:91`
- `roles/vault-configure/templates/policy-admin.hcl.j2:5`
- `roles/vault-configure/templates/policy-admin.hcl.j2:29`
- `roles/vault-configure/defaults/main.yaml:36`

Recommendation: create read-only AppRoles or policies per automation class, for example `ansible-infra-read`, `ansible-k3s-read`, and `eso-read`. Use admin/root only for Vault configuration and controlled secret writes. Prefer `community.hashi_vault` auth via AppRole or a short-lived token instead of a 1-year admin token in every service run.

### 4. High: `ansible.cfg` makes local validation brittle

`ansible.cfg` hardcodes `vault_password_file = ~/avpass`. That file exists on the Ansible host by convention, but not necessarily in local workspaces. Local `ansible-playbook --syntax-check` and `ansible-lint` fail immediately unless the operator overrides the vault password file.

References:
- `ansible.cfg:3`

Observed:
- `ansible-playbook --syntax-check baseline.yaml` failed with `/home/jason/avpass was not found` until `ANSIBLE_VAULT_PASSWORD_FILE=/tmp/ansible-vault-pass` was set.
- `ansible-lint` also reported many internal syntax-check failures for the same reason until the override was supplied.

Recommendation: remove the hardcoded password file from repo config and document `--vault-password-file ~/avpass` for the Ansible host workflow, or use an environment-specific wrapper script on the Ansible host.

### 5. High: several secret-bearing templates can leak secrets in Ansible diff/log output

Many templates contain passwords, API keys, database URLs, or LDAP bind credentials, but their render tasks do not use `no_log: true` or `diff: false`. Ansible normal output is usually quiet, but `--diff`, verbose failures, callbacks, or third-party logging can expose rendered secrets.

Examples:
- LiteLLM config contains `master_key` and oMLX API keys, rendered without `no_log`.
  - `roles/litellm/tasks/main.yaml:21`
  - `roles/litellm/templates/config.yaml.j2:2`
  - `roles/litellm/templates/config.yaml.j2:45`
- Open WebUI Compose contains LDAP and OpenAI-compatible keys, rendered without `no_log`.
  - `roles/open-webui/tasks/main.yaml:28`
  - `roles/open-webui/templates/compose.yaml.j2:23`
  - `roles/open-webui/templates/compose.yaml.j2:31`
- LLDAP Compose contains JWT, LDAP admin password, and PostgreSQL password.
  - `roles/lldap/tasks/main.yaml:30`
  - `roles/lldap/templates/compose.yaml.j2:12`
  - `roles/lldap/templates/compose.yaml.j2:17`
- Harbor configuration contains admin and DB passwords.
  - `roles/harbor/tasks/main.yaml:78`
  - `roles/harbor/templates/harbor.yml.j2:8`
  - `roles/harbor/templates/harbor.yml.j2:52`
- Grafana, pgAdmin, Vikunja, n8n, AnythingLLM, web-memory, blocklist, Hermes env/config, and ai-validation have similar patterns.

Recommendation: add `no_log: true` or at least `diff: false` to secret-bearing template/copy tasks. A clean pattern is to put secrets in `0600` env files and keep non-secret Compose files separate.

### 6. High: Technitium tasks expose API tokens and TSIG secrets

The Technitium role logs and debugs secret-bearing data. It logs the API login response on failures, stores and uses the token in URL query strings, and explicitly debugs current and rendered TSIG payloads. The TSIG payload includes `sharedSecret`, base64-encoded but still secret material.

References:
- `roles/technitium-dns/tasks/main.yaml:68`
- `roles/technitium-dns/tasks/main.yaml:92`
- `roles/technitium-dns/tasks/main.yaml:198`
- `roles/technitium-dns/tasks/main.yaml:217`
- `roles/technitium-dns/tasks/main.yaml:222`
- `roles/technitium-dns/tasks/main.yaml:238`
- `roles/technitium-dns/tasks/main.yaml:246`
- `roles/technitium-dns/tasks/main.yaml:269`

Recommendation: remove the debug tasks or gate them behind an explicit non-default debug variable plus redaction. Add `no_log: true` to login, token-bearing API requests, and TSIG reconciliation.

### 7. High: `vault-populate.yaml` can silently preserve stale secrets and fails on Hermes token shape drift

`vault-populate.yaml` only writes a secret if the path is missing. It does not update changed values, so rotations in the source Ansible Vault file will not propagate. It also hardcodes Hermes Discord keys `admin`, `jessica`, `chat`, `research`, and `coding`, while the current example only documents `admin` and `jessica`.

References:
- `vault-populate.yaml:56`
- `vault-populate.yaml:60`
- `vault-populate.yaml:62`
- `vault-populate.yaml:108`
- `vault-populate.yaml:121`
- `vault-populate.yaml:134`
- `vars/common/example-secrets.yaml:105`
- `vars/common/example-secrets.yaml:107`
- `vars/common/example-secrets.yaml:109`

Recommendation: make the population behavior explicit: `create-only`, `upsert`, or `rotate`. Validate required source vars before any write, skip optional missing keys intentionally, and derive map-shaped secrets from the existing dict instead of hardcoding profile keys.

### 8. High: migration state is inconsistent across playbooks and docs

Some playbooks now load `vars/vault-secrets.yaml`, but several active playbooks still rely only on Ansible Vault secrets. The docs still describe many secrets as living in `vars/common/secrets.yaml` or `vars/<env>/secrets.yaml`.

Examples:
- `web-memory.yaml` does not load `vars/vault-secrets.yaml`, but it uses `vault_openwebui_web_memory_postgres_password`.
  - `web-memory.yaml:5`
  - `web-memory.yaml:10`
- `dns.yaml` does not load `vars/vault-secrets.yaml`, but common vars build TSIG keys from vault variables.
  - `dns.yaml:3`
  - `vars/common/vars.yaml:135`
- `grafana.yaml` and `pgadmin.yaml` still load only `vars/common/secrets.yaml`.
  - `grafana.yaml:6`
  - `pgadmin.yaml:6`
- README still says the AI stack secrets are loaded from `vars/common/secrets.yaml`.
  - `README.md:32`
- `roles/vault/README.md` says no Ansible Vault secrets are required for Vault, but `vault.yaml` loads `vars/common/secrets.yaml` and the active defaults enable TLS that requires `vault_traefik_tls_cert` and `vault_traefik_tls_key`.
  - `roles/vault/README.md:129`
  - `vault.yaml:6`
  - `vars/common/vars.yaml:50`
  - `roles/vault/tasks/main.yaml:121`
  - `roles/vault/tasks/main.yaml:131`

Recommendation: create a secrets inventory table with columns for owner, source of truth, Vault path, Ansible variable, consumer playbooks, and migration status. Until migration is complete, label which secrets intentionally remain in Ansible Vault because they bootstrap Vault, K3s, SOPS, or Step CA.

### 9. Medium: validation baseline is noisy and archived playbooks break lint

`ansible-lint` currently fails with 83 fatal violations after providing a local temp directory and a dummy vault password file. Two unskippable syntax failures come from archived playbooks referencing roles that no longer exist in the active role path.

References:
- `.ansible-lint:1`
- `archive/playbooks/openclaw.yaml:26`
- `archive/playbooks/registry.yaml:24`

Observed lint categories included syntax-check, command-instead-of-module, partial-become, risky-file-permissions, ignore-errors, no-changed-when, no-handler, var-naming, FQCN, and formatting.

Recommendation: either exclude `archive/**` from lint, or make archived playbooks self-contained with `roles_path`. Then fix or baseline the remaining active violations so `ansible-lint` becomes a useful regression gate instead of background noise.

### 10. Medium: artifact provenance and reproducibility are weak

Many Compose roles use floating tags such as `latest`, `stable`, `main-stable`, or `v3` with `pull_policy: always`. Several roles install software via `curl | bash`, and the Vault role defines a checksum URL but does not verify the downloaded Vault zip.

References:
- `roles/grafana/defaults/main.yaml:7`
- `roles/n8n/defaults/main.yaml:7`
- `roles/ollama/defaults/main.yaml:3`
- `roles/prometheus/defaults/main.yaml:7`
- `roles/searxng/defaults/main.yaml:7`
- `roles/vikunja/defaults/main.yaml:7`
- `roles/technitium-dns/tasks/main.yaml:37`
- `roles/k3s-cluster/tasks/main.yml:122`
- `roles/vault/defaults/main.yaml:6`
- `roles/vault/tasks/main.yaml:65`

Recommendation: pin infrastructure services to explicit versions or digests, especially Vault, Grafana, Prometheus, Traefik, Harbor dependencies, and databases. For installer scripts, prefer package repositories, checksum verification, or downloaded scripts with pinned versions and validation.

### 11. Medium: idempotence is uneven

Some tasks are intentionally always-changing or mask failures. Examples include `setcap` always reporting changed, policy writes always changed, Harbor robot creation always changed, and Technitium zone/record operations using `failed_when: false`.

References:
- `roles/vault/tasks/main.yaml:84`
- `roles/vault/tasks/main.yaml:86`
- `roles/vault-configure/tasks/main.yaml:50`
- `roles/vault-configure/tasks/main.yaml:56`
- `roles/harbor/tasks/main.yaml:244`
- `roles/harbor/tasks/main.yaml:270`
- `roles/technitium-dns/tasks/main.yaml:274`
- `roles/technitium-dns/tasks/main.yaml:328`

Recommendation: use `changed_when` based on actual stdout/status where practical, use `failed_when` with known duplicate/error conditions instead of blanket false, and keep "always upsert" behavior documented for Vault policies.

### 12. Medium: K3s and bootstrap secret handling need stronger cleanup/no-log semantics

K3s installer tasks pass `K3S_TOKEN` in task environment without `no_log`, and failure diagnostics print installer stdout/stderr. K3s bootstrap renders Argo CD repository and SOPS age key secrets into a temporary directory and only removes that directory at the end of a successful run.

References:
- `roles/k3s-cluster/tasks/main.yml:120`
- `roles/k3s-cluster/tasks/main.yml:129`
- `roles/k3s-cluster/tasks/main.yml:146`
- `roles/k3s-cluster/tasks/main.yml:177`
- `roles/k3s-cluster/tasks/main.yml:185`
- `roles/k3s-bootstrap/tasks/main.yaml:50`
- `roles/k3s-bootstrap/tasks/main.yaml:56`
- `roles/k3s-bootstrap/tasks/main.yaml:68`
- `roles/k3s-bootstrap/tasks/main.yaml:121`

Recommendation: add `no_log` to token-bearing installer tasks or redact failure diagnostics. Wrap bootstrap temp file creation/apply/cleanup in `block`/`always` so secret manifests are removed on failure too.

### 13. Medium: role structure is good but common workflow code is duplicated

Most service playbooks repeat the same "wait for apt locks" shell block even though role apt tasks already use `lock_timeout` in many places. Database provisioning for service-specific PostgreSQL users is also repeated in top-level playbooks.

References:
- `harbor.yaml:52`
- `openwebui.yaml:55`
- `kanban.yaml:52`
- `hermes.yaml:11`
- `roles/common/tasks/main.yaml:1`
- `roles/updates/tasks/main.yaml:2`

Recommendation: move apt lock waiting into a reusable preflight role if it is still needed, or rely on apt `lock_timeout`. Factor recurring PostgreSQL database/user provisioning into a small role or task include.

### 14. Medium: active docs lag the new Vault model

The documentation still assumes Ansible Vault is the dominant secret store. That is useful for bootstrap, but it is confusing now that runtime infra secrets are moving to HashiCorp Vault.

Examples:
- README commands mix `--ask-vault-pass` and `--vault-password-file`.
  - `README.md:45`
  - `README.md:55`
  - `README.md:126`
- README still says wildcard TLS is at `secret/k3s/wildcard-tls`, while `vault-populate.yaml` moved it to `secret/infra/traefik/wildcard-tls`.
  - `README.md:116`
  - `vault-populate.yaml:14`
  - `vault-populate.yaml:138`
- `VAULT_BACKUP_ROLLBACK.md` is still centered on backing up Ansible Vault files, not HashiCorp Vault snapshots/exports.
  - `VAULT_BACKUP_ROLLBACK.md:3`
  - `VAULT_BACKUP_ROLLBACK.md:30`

Recommendation: add a top-level `docs/secrets.md` or update the README with the new source-of-truth split: bootstrap Ansible Vault, HashiCorp Vault runtime infra secrets, SOPS GitOps workload secrets, and offline break-glass material.

### 15. Low/Medium: permissions are sometimes broader than needed

Several Compose files containing secrets are rendered `0644`, and some service directories are world-readable or world-writable. The most visible example is AnythingLLM storage mode `0777`.

References:
- `roles/litellm/tasks/main.yaml:30`
- `roles/open-webui/tasks/main.yaml:28`
- `roles/lldap/tasks/main.yaml:30`
- `roles/anythingllm/tasks/main.yaml:16`
- `roles/anythingllm/tasks/main.yaml:22`

Recommendation: split secrets into env files with `0600` or `0640` and keep Compose files non-secret. Avoid `0777` unless the container truly requires it and document why.

### 16. Low/Medium: role metadata and automated tests are minimal

Roles generally do not have `meta/argument_specs.yml`, Molecule scenarios, or role-level tests. That is acceptable for a homelab at first, but the repo now manages enough critical infrastructure that lightweight role contracts would pay off.

Recommendation: start with role argument specs for `vault`, `vault-configure`, `k3s-cluster`, `technitium-dns`, and shared Compose service roles. Add a CI or local lint target that runs syntax checks for active playbooks only.

## Validation Performed

Safe local checks only:

- `ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_VAULT_PASSWORD_FILE=/tmp/ansible-vault-pass ansible-playbook --syntax-check baseline.yaml` - passed.
- `ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_VAULT_PASSWORD_FILE=/tmp/ansible-vault-pass ansible-playbook --syntax-check vault-populate.yaml` - passed.
- `ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_VAULT_PASSWORD_FILE=/tmp/ansible-vault-pass ansible-playbook --syntax-check hermes.yaml` - passed with deprecation warnings for `ansible.builtin.apt_repository` in the Hermes role.
- `ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_VAULT_PASSWORD_FILE=/tmp/ansible-vault-pass ansible-playbook --syntax-check dns.yaml` - passed.
- `ANSIBLE_LOCAL_TEMP=/tmp/ansible-local ANSIBLE_VAULT_PASSWORD_FILE=/tmp/ansible-vault-pass ansible-lint` - failed with 83 fatal violations.

Initial validation attempts without environment overrides failed because:

- Ansible tried to write local temp files under `/home/jason/.ansible/tmp`, which is read-only in this workspace.
- The repo `ansible.cfg` points at `/home/jason/avpass`, which is expected on the Ansible host but absent locally.

## Recommended Remediation Order

1. Fix `sync-to-ansible.sh` protections before the next broad sync, especially if anyone might use `--delete`.
2. Define and document the secret source-of-truth matrix.
3. Replace runtime `vault_admin_token` lookups with least-privilege Vault auth.
4. Add `no_log` or `diff: false` to secret-bearing template/API tasks, starting with Technitium and Compose env/config templates.
5. Make `vault-populate.yaml` explicit about create-only vs upsert behavior and validate optional map keys.
6. Remove `vault_password_file = ~/avpass` from repo config or move it into host-specific wrapper workflow.
7. Exclude or repair archived playbooks so `ansible-lint` can become a reliable active-project gate.
8. Pin service images/installers and verify downloaded artifacts where practical.
9. Reduce duplicated pre_tasks and database provisioning blocks after the high-risk secret work is complete.

## Notes

- Files were not synced to the Ansible host.
- No playbooks were run on the Ansible host.
- No Vault secret locations were modified.
- This review intentionally does not propose removing Ansible Vault entirely. Some bootstrap secrets may reasonably remain there until Vault auth, recovery, and snapshot workflows are fully settled.
