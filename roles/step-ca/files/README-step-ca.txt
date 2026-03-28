Step CA bootstrap instructions
=============================

This playbook prepared the host for `step-ca` by creating the `step` user,
directories under `/var/lib/step` and `/etc/step`, and installing a systemd
unit template at `/etc/systemd/system/step-ca.service`.

Manual initialization (recommended):

1. Install the `step` CLI on Ubuntu/Debian. Two options:

- Recommended (binary release):

   Download the official Linux tarball and install the `step` binary:

   curl -L -o /tmp/step_linux_amd64.tar.gz https://github.com/smallstep/cli/releases/latest/download/step_linux_amd64.tar.gz
   tar -xzf /tmp/step_linux_amd64.tar.gz -C /tmp
   sudo mv /tmp/step /usr/local/bin/step
   sudo chmod 0755 /usr/local/bin/step

- Alternative (package repo): follow the upstream instructions at https://smallstep.com/docs/ for distro package setup.

2. Run the interactive initializer on the host to create the CA material:

   sudo -u {{ step_ca_user }} -H bash -c "step ca init --name '{{ step_ca_hostname }}' --dns '{{ step_ca_hostname }}' --provisioner admin"

   If you prefer non-interactive, provide `--password-file` and other flags as needed.

3. After `step ca init` finishes it will create configuration under
   `{{ step_ca_config_dir }}` and secrets under `{{ step_ca_home }}`. Ensure
   the files are owned by the `{{ step_ca_user }}` user.

4. Start the service:

   sudo systemctl daemon-reload
   sudo systemctl enable --now {{ step_ca_service_name }}

5. Backup the root / intermediate key material immediately and store offline.

Notes:
- This role does not perform full automated CA initialization to avoid
  embedding sensitive keys in playbooks. If you want a fully automated
  flow, tell me and I will add a secure non-interactive init path (requires
  storing a vault secret for the CA password).
