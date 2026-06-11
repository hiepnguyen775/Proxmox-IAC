# =============================================
#  modules/storage/main.tf
#  Ceph RBD pool + storage definitions
# =============================================

variable "primary_node" { type = string }
variable "nodes"        { type = map(string) }

# Ceph pool cho VM disks
resource "proxmox_virtual_environment_ceph_pool" "vm_pool" {
  node_name = var.primary_node
  name      = "ceph-vm"

  pg_num        = 32    # Tăng lên 64-128 cho production
  pg_autoscale  = true
  size          = 3     # Số replica
  min_size      = 2     # Minimum để chấp nhận write

  application = "rbd"
}

# Ceph pool cho CephFS (shared storage)
resource "proxmox_virtual_environment_ceph_pool" "fs_pool_data" {
  node_name   = var.primary_node
  name        = "cephfs-data"
  pg_num      = 32
  pg_autoscale = true
  size        = 3
  min_size    = 2
  application = "cephfs"
}

resource "proxmox_virtual_environment_ceph_pool" "fs_pool_meta" {
  node_name   = var.primary_node
  name        = "cephfs-metadata"
  pg_num      = 16
  pg_autoscale = true
  size        = 3
  min_size    = 2
  application = "cephfs"
}

# Đăng ký Ceph storage trên tất cả nodes
resource "proxmox_virtual_environment_storage" "ceph_vm" {
  datastore_id = "ceph-vm"
  node_name    = var.primary_node
  type         = "rbd"

  content_types = ["images", "rootdir"]

  rbd {
    pool     = proxmox_virtual_environment_ceph_pool.vm_pool.name
    username = "admin"
    krbd     = false
  }

  depends_on = [proxmox_virtual_environment_ceph_pool.vm_pool]
}
