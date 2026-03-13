# Technitium DNS Role

This Ansible role installs and configures Technitium DNS Server, and optionally manages DNS zones and records.

## Features

- Installs Technitium DNS Server
- Configures basic DNS settings
- **Optional**: Manages DNS zones and records via API (disabled by default)

## Variables

### Installation Variables

- `technitium_install_script_url`: URL to download the installation script (default: official URL)
- `technitium_force_upgrade`: Force upgrade of Technitium DNS (default: false)
- `technitium_bootstrap_nameserver_primary`: Primary bootstrap nameserver (default: 1.1.1.1)
- `technitium_bootstrap_nameserver_secondary`: Secondary bootstrap nameserver (default: 8.8.8.8)
- `technitium_local_nameserver`: Local nameserver IP (default: 127.0.0.1)
- `technitium_fallback_nameserver`: Fallback nameserver IP (default: 1.1.1.1)

### Zone Management Variables (Optional)

**Zone management is disabled by default.** To enable, set `technitium_zones` to a list of zones.

- `technitium_api_url`: Technitium API URL (default: "http://localhost:5380")
- `technitium_username`: API username (default: "admin")
- `technitium_password`: API password (default: "admin") - **CHANGE THIS!**

- `technitium_zones`: List of zones to manage (default: `[]` - disabled)
  - `name`: Zone name (e.g., "local")
  - `type`: Zone type ("Primary", "Secondary", etc.)
  - `update`: Optional dynamic update policy for the zone
  - `update_network_acl`: Optional list of source IPs/CIDRs allowed to submit RFC2136 updates when using a network ACL-based update policy
  - `records`: List of DNS records for the zone

## DNS Record Types Supported

The role supports the following DNS record types:

- **A**: IPv4 address records
  - `ipAddress`: The IPv4 address
- **AAAA**: IPv6 address records
  - `ipAddress`: The IPv6 address
- **CNAME**: Canonical name records
  - `cname`: The canonical domain name
- **NS**: Name server records
  - `nameServer`: The name server domain name
- **PTR**: Pointer records
  - `ptrName`: The domain name to point to
- **TXT**: Text records
  - `text`: The text content
- **MX**: Mail exchange records
  - `preference`: Mail server preference
  - `exchange`: Mail server domain name
- **SRV**: Service location records
  - `priority`: Service priority
  - `weight`: Service weight
  - `port`: Service port
  - `target`: Service target domain

## Example Configuration

```yaml
technitium_zones:
  - name: "local"
    type: "Primary"
    update: "UseSpecifiedNetworkACL"
    update_network_acl:
      - "192.168.50.0/24"
    records:
      - domain: "dns.local"
        type: "A"
        ipAddress: "192.168.1.10"
        ttl: 3600
      - domain: "router.local"
        type: "A"
        ipAddress: "192.168.1.1"
        ttl: 3600
      - domain: "www.local"
        type: "CNAME"
        cname: "server.local"
        ttl: 3600
      - domain: "mail.local"
        type: "MX"
        preference: 10
        exchange: "mailserver.local"
        ttl: 3600
```

## Usage

1. Update the variables in `defaults/main.yaml` or override them in your playbook/group_vars/host_vars
2. **Important**: Change the default API credentials!
3. Customize the `technitium_zones` list with your local DNS records
4. Run the playbook

## Security Notes

- The default API credentials are `admin`/`admin` - change these immediately
- Consider using Ansible Vault to encrypt sensitive credentials
- The API calls use HTTP by default; consider enabling HTTPS for production use
- RFC2136 updates should be limited to trusted K3s node ranges or protected with TSIG if you move away from insecure updates

## ExternalDNS Example

To let ExternalDNS update `taylor.lan` from a K3s cluster running on `192.168.50.0/24`:

```yaml
technitium_zones:
  - name: "taylor.lan"
    type: "Primary"
    update: "UseSpecifiedNetworkACL"
    update_network_acl:
      - "192.168.50.0/24"
```

## Troubleshooting

- Check Technitium DNS logs: `journalctl -u dns.service`
- Verify API connectivity: `curl -X POST http://localhost:5380/api/user/login -d "user=admin&pass=admin"`
- Zone management requires the DNS service to be running and accessible via API