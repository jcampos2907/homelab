# Proxmox API
pm_api_url          = "https://pve.famcr.org:8006/api2/json"
pm_api_token_id     = "terraform@pve!tf"
pm_api_token_secret = "REDACTED"
pm_tls_insecure     = true

# Use something reachable for scp (IP or DNS)
pm_host_ssh = "pve.famcr.org"

# Proxmox placement / Ubuntu Server LTS template
pm_node     = "pve"
vm_template = "ubuntu-24.04-cloudinit"     # Ubuntu Server LTS cloud-init template
vm_storage  = "local-lvm"
vm_bridge   = "vmbr0"

# VM sizes
vm_cpus   = 2
vm_memory = 4096
vm_disk_gb = 40

# LAN NIC addresses (for OS bring-up only)
srv_ip_cidr   = "192.168.1.50/24"
agent_ip_cidr = "192.168.1.51/24"
gw            = "192.168.1.1"
dns           = "1.1.1.1"

# Auth
ssh_pubkey         = "ssh-ed25519 AAAA... juan@mac"
jcampos_pass_hash  = "$y$j9T$REPLACE_WITH_A_YESCRYPT_HASH"   # mkpasswd -m yescrypt

# Tailscale / k3s
tailscale_auth_key = "tskey-auth-REPLACE"       # use an ephemeral, auto-approve tagged key
k3s_version        = "v1.30.4+k3s1"
k3s_token          = "super-long-random-token"

# Hostnames (MagicDNS)
srv_hostname   = "k3s-srv-1"
agent_hostname = "k3s-agent-1"
