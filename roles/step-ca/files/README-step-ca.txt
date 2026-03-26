Step CA bootstrap instructions
=============================

This playbook prepared the host for `step-ca` by creating the `step` user,
directories under `/var/lib/step` and `/etc/step`, and installing a systemd
unit template at `/etc/systemd/system/step-ca.service`.

Manual initialization (recommended):

1. Install the `step` CLI on Ubuntu/Debian using the official package repository (recommended):

   curl -s https://packagecloud.io/install/repositories/smallstep/cli/script.deb.sh | sudo bash
   sudo apt-get update
   sudo apt-get install -y step

   Alternatively, you can install a binary release from GitHub if you prefer a manual install.

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
