# LLDAP Role

Deploys [LLDAP](https://github.com/lldap/lldap) — a lightweight LDAP server with a web UI — using Docker Compose, with Traefik-based web routing and a PostgreSQL backend on the shared prod database server.

## Host

| Hostname        | IP              |
|-----------------|-----------------|
| ldap.taylor.lan | 192.168.50.50   |

## Architecture

```
LDAP clients → port 3890 (TCP, exposed directly from container)
Browser       → Traefik (Host: ldap.taylor.lan) → lldap container :17170 (web UI)
LLDAP         → PostgreSQL prod (192.168.50.15) database: lldap
```

- **LDAP port 3890** is exposed directly on the host for standard LDAP client access. Clients use `ldap://ldap.taylor.lan:3890`.
- **Web UI** is routed through Traefik using host-based routing at `http://ldap.taylor.lan`.
- **Storage**: PostgreSQL prod (`192.168.50.15`, database `lldap`, user `lldap`). The first play in the playbook provisions the database and user automatically via `community.postgresql`.

## Secrets Required

Set these in `vars/common/secrets.yaml` on the Ansible host before running the playbook:

| Variable | Description |
|---|---|
| `vault_lldap_jwt_secret` | JWT signing secret for the LLDAP web API |
| `vault_lldap_ldap_user_pass` | Admin LDAP bind password (the `admin` user in LLDAP) |
| `vault_lldap_db_password` | PostgreSQL password for the `lldap` database user |

Generate secrets on the Ansible host:
```bash
# JWT secret (32+ chars)
openssl rand -hex 32

# LDAP admin password
openssl rand -hex 16

# DB password
openssl rand -hex 24
```

Edit the vault:
```bash
ansible-vault edit vars/common/secrets.yaml --vault-password-file ~/avpass
```

## Role Variables

Key variables (see `defaults/main.yaml` for the full list):

| Variable | Default | Description |
|---|---|---|
| `lldap_image` | `lldap/lldap:stable` | Docker image |
| `lldap_base_dn` | `dc=taylor,dc=lan` | LDAP base distinguished name |
| `lldap_ldap_user_dn` | `admin` | Admin username in LLDAP |
| `lldap_ldap_port` | `3890` | LDAP TCP port (exposed on host) |
| `lldap_db_host` | `192.168.50.15` | PostgreSQL server |
| `lldap_db_name` | `lldap` | Database name |
| `lldap_traefik_hostname` | `ldap.taylor.lan` | Traefik host rule |
| `lldap_traefik_entrypoint` | `web` | Traefik entrypoint |

## TLS With Traefik

TLS termination for the LLDAP UI should be handled in Traefik using your existing Step CA workflow and Traefik entrypoint/certificate configuration.

## Running the Playbook

The playbook has two plays:
1. **Provision DB** — runs on `postgres_prod` (192.168.50.15), creates the `lldap` user and database.
2. **Deploy LLDAP** — runs on `ldap` (mapped to `lldap` inventory host group), deploys Docker Compose stack.

From the Ansible host (`192.168.50.11`):

```bash
ssh 192.168.50.11
cd ~/ansible
ansible-playbook ldap.yaml --vault-password-file ~/avpass
```

## Initial Login

Once the stack is up, the web UI is at `http://ldap.taylor.lan`.

Default admin credentials:
- **Username**: `admin`  
- **Password**: the value of `vault_lldap_ldap_user_pass`

**Change the admin password via the web UI immediately after first login** if it was set to a weak value.

## LDAP Client Configuration

Use these settings in applications (e.g. Vault, Gitea, Nextcloud):

| Setting | Value |
|---|---|
| LDAP URL | `ldap://ldap.taylor.lan:3890` |
| Base DN | `dc=taylor,dc=lan` |
| Bind DN | `cn=admin,ou=people,dc=taylor,dc=lan` |
| Bind password | `vault_lldap_ldap_user_pass` |
| User filter | `(&(objectClass=person)(uid=%s))` |
| Group filter | `(member=cn=%s,ou=people,dc=taylor,dc=lan)` |

> If TLS is enabled on Vault or other services, consider upgrading to LDAPS. LLDAP supports LDAPS via `LLDAP_LDAPS_*` env vars (add to compose template and expose port 6360).

## Directory Layout

```
roles/lldap/
├── README.md
├── defaults/
│   └── main.yaml           # All role variables with defaults
├── handlers/
│   └── main.yaml           # systemd restart handlers
├── tasks/
│   └── main.yaml           # Directories, templates, systemd, health check
└── templates/
    ├── compose.yaml.j2     # Docker Compose (lldap + Traefik labels)
    └── lldap.service.j2    # systemd unit
```
