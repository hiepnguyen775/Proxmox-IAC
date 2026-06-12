terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
  # Cấu hình remote state nằm ở backend.tf
}

provider "proxmox" {
  # URL của bất kỳ node nào trong cluster (nên trỏ vào VIP nếu có HA proxy)
  endpoint = var.proxmox_endpoint

  # Format: "USER@REALM!TOKEN_ID=SECRET"
  # Ví dụ: "terraform@pve!tf-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  api_token = var.proxmox_api_token

  # Bật khi dùng self-signed cert (lab). Production nên dùng cert hợp lệ.
  insecure = var.proxmox_insecure

  # SSH dùng để upload ISO, cloud-init snippets
  ssh {
    agent    = true
    username = var.proxmox_ssh_user
    # private_key = file("~/.ssh/id_rsa")  # nếu không dùng ssh-agent
  }
}
