variable "vm_name"       { type = string }
variable "vm_id"         { type = number }
variable "node_name"     { type = string }
variable "description"   { type = string; default = "" }
variable "tags"          { type = string; default = "" }
variable "template_vm_id" { type = number }
variable "cpu_cores"     { type = number; default = 2 }
variable "memory_mb"     { type = number; default = 2048 }
variable "disk_gb"       { type = number; default = 20 }
variable "storage_pool"  { type = string }
variable "bridge"        { type = string; default = "vmbr0" }
variable "ip_address"    { type = string }
variable "gateway"       { type = string }
variable "vlan_id"       { type = number; default = null; nullable = true }
variable "dns_server"    { type = string; default = "1.1.1.1" }
variable "dns_domain"    { type = string; default = "local" }
variable "ssh_public_key" { type = string }
variable "username"      { type = string; default = "ubuntu" }
