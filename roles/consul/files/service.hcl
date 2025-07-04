# service.hcl
service {
  name = "web"
  port = 80
  check {
    http = "http://localhost:80/health"
    interval = "10s"
    timeout = "5s"
  }
}