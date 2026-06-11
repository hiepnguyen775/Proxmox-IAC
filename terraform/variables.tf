# =============================================
#  PROXMOX CONNECTION
# =============================================

variable "proxmox_endpoint" {
  description = "URL Proxmox API — trỏ vào node primary hoặc VIP"
  type        = string
  default     = "https://192.168.1.10:8006"
}

variable "proxmox_api_token" {
  description = "API token — format: user@realm!token-id=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Bỏ qua TLS verify (lab only)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user để upload snippets lên Proxmox node"
  type        = string
  default     = "root"
}

# =============================================
#  CLUSTER NODES
# =============================================

variable "proxmox_nodes" {
  description = "Map tên node → IP. Thêm node mới vào đây là đủ."
  type        = map(string)
  default = {
    "pve-node-01" = "192.168.1.10"
    "pve-node-02" = "192.168.1.11"
    "pve-node-03" = "192.168.1.12"
    # "pve-node-04" = "192.168.1.13"  # uncomment khi join node mới
  }
}

# =============================================
#  VM DEFAULTS
# =============================================

variable "vm_template_id" {
  description = "ID của cloud-init template đã tạo sẵn"
  type        = number
  default     = 9000
}

variable "vm_ssh_public_key" {
  description = "SSH public key inject vào cloud-init"
  type        = string
}

variable "vm_default_user" {
  description = "Default OS user trong VM"
  type        = string
  default     = "ubuntu"
}

variable "vm_dns_server" {
  description = "DNS server cho cloud-init"
  type        = string
  default     = "1.1.1.1"
}

variable "vm_dns_domain" {
  description = "Search domain"
  type        = string
  default     = "lab.local"
}

# =============================================
#  STORAGE
# =============================================

variable "storage_vm_pool" {
  description = "Tên storage pool cho VM disk"
  type        = string
  default     = "local-lvm"  # đổi thành "ceph-vm" khi Ceph đã setup
}

variable "storage_iso_pool" {
  description = "Storage pool chứa ISO và snippets"
  type        = string
  default     = "local"
}

# =============================================
#  NETWORK
# =============================================

variable "vm_bridge" {
  description = "Linux bridge mặc định"
  type        = string
  default     = "vmbr0"
}

variable "vm_gateway" {
  description = "Default gateway cho VM"
  type        = string
  default     = "192.168.1.1"
}

variable "vm_network_prefix" {
  description = "Network prefix /CIDR"
  type        = string
  default     = "24"
}

# =============================================
#  VM DEFINITIONS  (định nghĩa từng VM cụ thể)
# =============================================

variable "vm_definitions" {
  description = "Map định nghĩa các VM cần tạo"
  type = map(object({
    vm_id       = number
    node        = string   # tên node Proxmox
    cpu_cores   = number
    memory_mb   = number
    disk_gb     = number
    ip_address  = string   # CIDR notation, ví dụ "192.168.1.101/24"
    vlan_id     = optional(number, null)
    tags        = list(string)
    description = optional(string, "")
  }))
  default = {}
}

# =============================================
#  LXC DEFINITIONS
# =============================================

variable "lxc_definitions" {
  description = "Map định nghĩa LXC containers"
  type = map(object({
    ct_id      = number
    node       = string
    cpu_cores  = number
    memory_mb  = number
    disk_gb    = number
    ip_address = string
    tags       = list(string)
    os_template = string   # ví dụ "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  }))
  default = {}
}

# =============================================
#  CEPH
# =============================================

variable "ceph_enabled" {
  description = "Có deploy Ceph không"
  type        = bool
  default     = false
}

variable "ceph_network" {
  description = "Ceph public network CIDR"
  type        = string
  default     = "192.168.1.0/24"
}

variable "ceph_cluster_network" {
  description = "Ceph cluster (replication) network CIDR"
  type        = string
  default     = "10.10.10.0/24"
}

# =============================================
#  SDN
# =============================================

variable "sdn_enabled" {
  description = "Có tạo SDN zones không"
  type        = bool
  default     = false
}

variable "sdn_zones" {
  description = "Danh sách SDN zones cần tạo"
  type = list(object({
    zone_id = string
    type    = string  # "vlan" hoặc "vxlan"
    bridge  = string
  }))
  default = []
}
