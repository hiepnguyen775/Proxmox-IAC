# =============================================
#  modules/lxc/main.tf
# =============================================

resource "proxmox_virtual_environment_container" "this" {
  node_name  = var.node_name
  vm_id      = var.ct_id
  tags       = split(";", var.tags)
  started    = true
  on_boot    = true

  initialization {
    hostname = var.ct_name

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = 512
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  operating_system {
    template_file_id = var.os_template
    type             = "ubuntu"
  }

  # Unprivileged container (safer)
  unprivileged = true

  features {
    nesting = true   # bật nếu cần chạy Docker trong LXC
  }
}

variable "ct_name"       { type = string }
variable "ct_id"         { type = number }
variable "node_name"     { type = string }
variable "cpu_cores"     { type = number; default = 1 }
variable "memory_mb"     { type = number; default = 512 }
variable "disk_gb"       { type = number; default = 8 }
variable "ip_address"    { type = string }
variable "gateway"       { type = string }
variable "tags"          { type = string; default = "" }
variable "os_template"   { type = string }
variable "ssh_public_key" { type = string }
variable "storage_pool"  { type = string }

output "ip_address" { value = var.ip_address }
output "ct_id"      { value = proxmox_virtual_environment_container.this.vm_id }
