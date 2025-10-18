# --- Proxmox API ---
variable "pm_api_url"          { type = string }
variable "pm_api_token_id"     { type = string }
variable "pm_api_token_secret" { type = string }
variable "pm_tls_insecure"     { type = bool   default = true }

# For 'scp' when pushing snippets (use an IP or DNS you can reach from your laptop/runner)
variable "pm_host_ssh"         { type = string }  # e.g., "pve.famcr.org" or "192.168.1.10"

# --- Proxmox VM placement / template ---
variable "pm_node"     { type = string }                 # e.g., "pve"
variable "vm_template" { type = string }                 # e.g., "ubuntu-24.04-cloudinit"
variable "vm_storage"  { type = string }                 # e.g., "local-lvm"
variable "vm_bridge"   { type = string  default = "vmbr0" }

# --- VM shape ---
variable "vm_cpus"     { type = number  default = 2 }
variable "vm_memory"   { type = number  default = 4096 }   # MB
variable "vm_disk_gb"  { type = number  default = 40 }

# --- Proxmox NIC IPs (for OS bring-up only; k3s uses Tailscale) ---
variable "srv_ip_cidr"   { type = string } # "192.168.1.50/24"
variable "agent_ip_cidr" { type = string } # "192.168.1.51/24"
variable "gw"            { type = string } # "192.168.1.1"
variable "dns"           { type = string  default = "1.1.1.1" }

# --- Auth / users ---
variable "ssh_pubkey"        { type = string } # your SSH public key
variable "jcampos_pass_hash" { type = string } # yescrypt/SHA-512 hash (NOT plaintext)

# --- Tailscale / k3s ---
variable "tailscale_auth_key" { type = string } # tskey-auth-...
variable "k3s_version"        { type = string  default = "v1.30.4+k3s1" }
variable "k3s_token"          { type = string } # long random

# --- Hostnames (MagicDNS-friendly) ---
variable "srv_hostname"   { type = string  default = "k3s-srv-1" }
variable "agent_hostname" { type = string  default = "k3s-agent-1" }
