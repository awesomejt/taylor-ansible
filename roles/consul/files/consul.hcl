# consul.hcl

# Data directory for Consul state
data_dir = "/opt/consul"

# Bind address for the Consul server
bind_addr = "0.0.0.0" # Listen on all interfaces; replace with specific IP if needed

# Node name (unique for the node)
node_name = "consul-server-1"

# Enable server mode
server = true

# Bootstrap for a single-server cluster
bootstrap_expect = 1

# Data center name
datacenter = "dc1"

# Enable the UI (optional, for management)
ui_config {
  enabled = true
}

# Ports configuration, emphasizing DNS
ports {
  http  = 8500  # HTTP API
  https = -1    # Disable HTTPS (enable with certs for production)
  dns   = 8600  # DNS interface (standard DNS port)
  server = 8300 # Server-to-server RPC
  serf_lan = 8301 # LAN gossip protocol
}

# DNS configuration
dns_config {
  enable_truncate = true # Enable DNS truncation for large responses
  only_passing = true    # Only return services with passing health checks
  allow_stale = true     # Allow stale DNS queries for performance
  max_stale = "10m"      # Maximum staleness for stale queries
  node_ttl = "30s"       # TTL for node DNS responses
  service_ttl = "30s"    # TTL for service DNS responses
}

# Enable encryption for gossip protocol (optional for single node)
encrypt = "UGoK9dyBBdReRk2V+HQWXXqnKhuYMJ8i8DU4+vnaXTE=" # Generate with `consul keygen`

# Logging configuration
log_level = "INFO"

# Enable ACLs for security (recommended for production)
acl {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
}

# Telemetry (optional)
telemetry {
  prometheus_retention_time = "24h"
  disable_hostname = true
}