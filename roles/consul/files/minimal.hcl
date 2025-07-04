datacenter = "dc1"
bind_addr = "127.0.0.1"

connect {
  enabled = true
}

autopilot {
  min_quorum = 1
}

data_dir = "/opt/consul"
client_addr = "0.0.0.0"

ui_config{
  enabled = true
}

server = true
bootstrap_expect=1
retry_join = ["127.0.0.1"]