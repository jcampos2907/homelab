#cloud-config
preserve_hostname: true
hostname: ${hostname}
manage_etc_hosts: true

users:
  - name: jcampos
    gecos: "Juan Campos"
    groups: [sudo]
    shell: /bin/bash
    lock_passwd: false
    # Use a precomputed yescrypt/SHA-512 hash (avoid plaintext)
    passwd: "${jcampos_pass_hash}"
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - ${ssh_pubkey}

package_update: true
packages:
  - curl
  - ca-certificates
  - jq

write_files:
  - path: /usr/local/bin/ts-ip
    permissions: "0755"
    content: |
      #!/usr/bin/env bash
      tailscale ip -4 | head -n1

runcmd:
  # 1) Tailscale (Ubuntu Server LTS)
  - curl -fsSL https://tailscale.com/install.sh | sh
  - tailscale up --auth-key ${tailscale_auth_key} --ssh --accept-dns=true --hostname ${hostname}
  - /usr/local/bin/ts-ip | tee /etc/tailscale-ip

  # 2) k3s (server or agent), binding ONLY to tailnet IP
  - |
    set -eux
    NODE_IP="$(cat /etc/tailscale-ip)"
    if [ "${role}" = "server" ]; then
      export INSTALL_K3S_VERSION="${k3s_version}"
      INSTALL_K3S_EXEC="server \
        --cluster-init \
        --node-ip ${NODE_IP} \
        --advertise-address ${NODE_IP} \
        --tls-san ${NODE_IP} \
        --disable traefik"
      curl -sfL https://get.k3s.io | sh -s - ${INSTALL_K3S_EXEC}
      chmod 644 /etc/rancher/k3s/k3s.yaml
      sed -i "s/127.0.0.1/${NODE_IP}/" /etc/rancher/k3s/k3s.yaml
      echo "${k3s_token}" > /var/lib/rancher/k3s/server/token
      chmod 600 /var/lib/rancher/k3s/server/token
    else
      export INSTALL_K3S_VERSION="${k3s_version}"
      K3S_URL="https://${server_hostname}:6443"
      curl -sfL https://get.k3s.io | K3S_URL="${K3S_URL}" K3S_TOKEN="${k3s_token}" K3S_NODE_IP="${NODE_IP}" sh -
    fi
