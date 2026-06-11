terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  # ---------- Remote state (bật khi có S3/Minio) ----------
  # backend "s3" {
  #   bucket                      = "terraform-state"
  #   key                         = "proxmox/prod/terraform.tfstate"
  #   region                      = "ap-southeast-1"
  #   endpoint                    = "https://minio.example.com"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
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
