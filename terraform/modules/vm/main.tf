# =============================================
#  modules/vm/main.tf
#  Tạo QEMU/KVM VM từ cloud-init template
# =============================================

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.vm_name
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = split(";", var.tags)

  # Clone từ template
  clone {
    vm_id   = var.template_vm_id
    full    = true
    retries = 3
  }

  # CPU — x86-64-v2-AES tương thích tốt với live migration
  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "x86-64-v2-AES"
    numa    = false
  }

  # RAM
  memory {
    dedicated = var.memory_mb
    floating  = 0   # không dùng balloon cho k8s nodes
  }

  # Disk — virtio-scsi-single cho hiệu năng tốt nhất
  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = var.disk_gb
    file_format  = "raw"
  }

  # Network
  network_device {
    bridge  = var.bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  # Cloud-init
  initialization {
    datastore_id = var.storage_pool

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      server = var.dns_server
      domain = var.dns_domain
    }

    user_account {
      username = var.username
      keys     = [var.ssh_public_key]
    }
  }

  # Boot
  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  # Guest agent — cần cài qemu-guest-agent trong VM
  agent {
    enabled = true
    trim    = true
    type    = "virtio"
  }

  # VGA
  vga {
    type = "serial0"
  }

  serial_device {}

  # Start on create, auto-start on node boot
  started         = true
  on_boot         = true
  stop_on_destroy = true

  # Timeout cho clone (template lớn cần lâu hơn)
  timeout_clone        = 600
  timeout_start_vm     = 180
  timeout_shutdown_vm  = 120
  timeout_stop_vm      = 30

  lifecycle {
    # Không recreate VM khi chỉ đổi description hoặc tags
    ignore_changes = [description]
  }
}
