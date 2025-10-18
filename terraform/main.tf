locals {
  srv_snippet   = "${var.srv_hostname}-user.yaml"
  agent_snippet = "${var.agent_hostname}-user.yaml"
}

# Render cloud-init user-data for server
data "template_file" "srv_userdata" {
  template = file("${path.module}/cloud-init.yaml.tpl")
  vars = {
    hostname           = var.srv_hostname
    role               = "server"
    ssh_pubkey         = var.ssh_pubkey
    jcampos_pass_hash  = var.jcampos_pass_hash
    tailscale_auth_key = var.tailscale_auth_key
    k3s_version        = var.k3s_version
    k3s_token          = var.k3s_token
    server_hostname    = var.srv_hostname
  }
}

# Render cloud-init user-data for agent
data "template_file" "agent_userdata" {
  template = file("${path.module}/cloud-init.yaml.tpl")
  vars = {
    hostname           = var.agent_hostname
    role               = "agent"
    ssh_pubkey         = var.ssh_pubkey
    jcampos_pass_hash  = var.jcampos_pass_hash
    tailscale_auth_key = var.tailscale_auth_key
    k3s_version        = var.k3s_version
    k3s_token          = var.k3s_token
    server_hostname    = var.srv_hostname
  }
}

# Push the rendered user-data into Proxmox snippets
resource "null_resource" "push_snippets" {
  provisioner "local-exec" {
    command = <<EOT
mkdir -p /tmp/proxmox-snippets
cat > /tmp/proxmox-snippets/${local.srv_snippet} <<'EOF'
${data.template_file.srv_userdata.rendered}
EOF
cat > /tmp/proxmox-snippets/${local.agent_snippet} <<'EOF'
${data.template_file.agent_userdata.rendered}
EOF
scp /tmp/proxmox-snippets/${local.srv_snippet}   root@${var.pm_host_ssh}:/var/lib/vz/snippets/${local.srv_snippet}
scp /tmp/proxmox-snippets/${local.agent_snippet} root@${var.pm_host_ssh}:/var/lib/vz/snippets/${local.agent_snippet}
EOT
  }
}

# Server VM
resource "proxmox_vm_qemu" "srv" {
  depends_on  = [null_resource.push_snippets]
  name        = var.srv_hostname
  target_node = var.pm_node
  clone       = var.vm_template
  full_clone  = true
  agent       = 1

  os_type     = "cloud-init"
  ipconfig0   = "ip=${var.srv_ip_cidr},gw=${var.gw}"
  nameserver  = var.dns
  ciuser      = "jcampos"
  sshkeys     = var.ssh_pubkey

  scsihw      = "virtio-scsi-pci"
  cores       = var.vm_cpus
  sockets     = 1
  memory      = var.vm_memory

  disk {
    size     = "${var.vm_disk_gb}G"
    type     = "scsi"
    storage  = var.vm_storage
    iothread = 1
    discard  = "on"
  }

  network {
    model  = "virtio"
    bridge = var.vm_bridge
  }

  # Use the uploaded cloud-init user-data
  cicustom = "user=local:snippets/${local.srv_snippet}"
  onboot   = true
}

# Agent VM
resource "proxmox_vm_qemu" "agent" {
  depends_on  = [null_resource.push_snippets]
  name        = var.agent_hostname
  target_node = var.pm_node
  clone       = var.vm_template
  full_clone  = true
  agent       = 1

  os_type     = "cloud-init"
  ipconfig0   = "ip=${var.agent_ip_cidr},gw=${var.gw}"
  nameserver  = var.dns
  ciuser      = "jcampos"
  sshkeys     = var.ssh_pubkey

  scsihw      = "virtio-scsi-pci"
  cores       = var.vm_cpus
  sockets     = 1
  memory      = var.vm_memory

  disk {
    size     = "${var.vm_disk_gb}G"
    type     = "scsi"
    storage  = var.vm_storage
    iothread = 1
    discard  = "on"
  }

  network {
    model  = "virtio"
    bridge = var.vm_bridge
  }

  cicustom = "user=local:snippets/${local.agent_snippet}"
  onboot   = true
}

output "next_steps" {
  value = <<EON
When VMs are up:
  1) Pull kubeconfig:
     ssh jcampos@${var.srv_hostname} 'sudo cat /etc/rancher/k3s/k3s.yaml' > kubeconfig
  2) It already points to the server's tailnet IP; then:
     export KUBECONFIG=$PWD/kubeconfig
     kubectl get nodes -o wide
EON
}
