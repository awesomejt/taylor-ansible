# AGENTS.md

This file provides operating instructions for AI agents working in this Ansible project.

## Project Operating Rules

### Git Workflow

- Commit changes after completing a coherent unit of work.
- Do **not** push changes to any remote repository.
- Use clear, conventional commit messages when possible.
- Before committing, review the diff and ensure generated, temporary, or secret files are not accidentally included.

Recommended commit flow:

```bash
git status
git diff
git add <changed-files>
git commit -m "<clear summary of the work>"
```

Never run:

```bash
git push
```

unless the human operator explicitly instructs otherwise.

## Ansible Workflow

### Local Machine Responsibilities

Local Ansible commands are limited to validation and linting only.

Allowed local commands include:

```bash
ansible-playbook --syntax-check <playbook>.yaml
ansible-lint
```

Do not run real playbook changes locally.

### Syncing Files to the Ansible Host

Use the included sync script to upload project files to the Ansible host.

- The sync script requires no parameters.
- Run it before executing playbooks on the Ansible host.
- Prefer the project-provided script over manual `scp`, `rsync`, or ad hoc copying.

Example:

```bash
./sync-to-ansible.sh
```

If the script name differs in this repository, use the included sync script that performs the project upload to the Ansible host.

### Running Playbooks

Actual playbook execution must happen on the Ansible host:

```text
192.168.50.11
```

Connect to the Ansible host before running playbooks:

```bash
ssh 192.168.50.11
```

Run playbooks from the synced project location on that host in the `~/ansible` directory.

Do not run production-effecting playbooks directly from the local machine.

Provide instructions on how to run the playbooks when providing a summary of next steps in which next steps would include applying the playbook.

## Secrets and Ansible Vault

### Secret Storage Location

Secrets must be stored in Ansible Vault files on the Ansible host using this path pattern:

```text
vars/<env>/secrets.yaml
```

For playbooks/roles without a dev/staging/prod environment, the environment is `common`.

Examples:

```text
vars/dev/secrets.yaml
vars/staging/secrets.yaml
vars/prod/secrets.yaml
```

Do not commit plaintext secrets.

### Vault Password File

The Ansible Vault password file is located on the Ansible host at:

```text
~/avpass
```

Use this file when editing, encrypting, decrypting, viewing, or running playbooks that need vault access.

Examples to run on the Ansible host:

```bash
ansible-vault edit vars/<env>/secrets.yaml --vault-password-file ~/avpass
ansible-vault view vars/<env>/secrets.yaml --vault-password-file ~/avpass
ansible-playbook <playbook>.yaml --vault-password-file ~/avpass
```

### Generated Passwords

When generating a password or credential:

- Put the secret in the correct Ansible Vault file on the Ansible host.
- Do not store the plaintext value in regular repository files.
- In the final response, state either:
  - the generated password value, when appropriate for the human operator to record immediately, and/or
  - the exact vault location where it was stored.

Example response format:

```text
Generated password: <password>
Stored in: vars/<env>/secrets.yaml on 192.168.50.11
Vault key: <variable_name>
```

If revealing the password in the response would be inappropriate for the task, explain where it is located instead.

### Secret Examples

For any entry in the ansible-vault secrets, create a sanitized example-secrets.yaml entry - with a comment about what the entry 
is for and how to create it or where to find it.


## Persistent Project Memory

Use `MEMORY.md` to record important project decisions, assumptions, conventions, environment details, and rationale that should survive across sessions, model context compression, or different AI agents.

Record items such as:

- Architecture or inventory decisions.
- Naming conventions.
- Environment-specific assumptions.
- Manual steps that must not be forgotten.
- Reasons for choosing one implementation approach over another.

Keep entries concise, dated when helpful, and focused on information future agents need.

Do not use `MEMORY.md` for secrets.

## Task Tracking

Use `TODO.md` to track multi-step work.

For non-trivial tasks:

- Add or update a checklist in `TODO.md` before or during the work.
- Mark steps complete as they are finished.
- Leave clear notes for any blocked, skipped, or deferred work.

Suggested format:

```markdown
# TODO

## <Task Name>

- [ ] Step one
- [ ] Step two
- [ ] Validate with syntax check
- [ ] Sync to Ansible host
- [ ] Run playbook on Ansible host
- [ ] Commit changes locally
```

## Validation Expectations

Before committing, run appropriate local validation:

```bash
ansible-playbook --syntax-check <playbook>.yaml
ansible-lint
```

When validation requires inventory, variables, or vault access only available on the Ansible host, document that limitation in the response and perform the applicable validation or playbook run on the Ansible host.

## Response Expectations

When reporting completed work, include:

- Files changed.
- Local validation performed.
- Whether files were synced to the Ansible host.
- Playbooks run on the Ansible host, if any.
- Vault secret locations touched, without exposing secrets unless explicitly appropriate.
- Commit hash or commit message created.
- Any remaining TODOs or follow-up work.

## Safety Rules

- Do not push commits unless explicitly instructed.
- Do not commit plaintext secrets.
- Do not bypass the sync script for normal file upload workflow.
- Do not run actual playbooks locally.
- Do not edit vault secrets outside the Ansible host unless explicitly instructed and safe to do so.
- Do not remove or overwrite `MEMORY.md` or `TODO.md` without preserving useful existing content.
