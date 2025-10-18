terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox  = { source = "Telmate/proxmox", version = "~> 3.0" }
    template = { source = "hashicorp/template", version = "~> 2.2" }
  }
}
