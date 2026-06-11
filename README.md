# Proxmox IaC — Terraform + Ansible

## Cấu trúc repo

```
proxmox-iac/
├── terraform/
│   ├── providers.tf          # Provider bpg/proxmox config
│   ├── main.tf               # Root module — gọi các sub-module
│   ├── variables.tf          # Khai báo biến
│   ├── outputs.tf            # Output sau apply
│   ├── terraform.tfvars      # Giá trị thực (gitignore!)
│   ├── locals.tf             # Node map, VM definitions
│   └── modules/
│       ├── vm/               # Tạo QEMU/KVM VM
│       ├── lxc/              # Tạo LXC container
│       ├── network/          # SDN zone, vnet, vlan
│       ├── storage/          # Ceph pool, directory
│       └── ceph/             # Ceph OSD, MDS, MGR
├── ansible/
│   ├── inventory/
│   │   └── proxmox.yml       # Dynamic inventory
│   ├── group_vars/
│   │   ├── all.yml
│   │   └── vault.yml         # ansible-vault encrypted
│   ├── roles/
│   │   ├── base/             # OS hardening, timezone, packages
│   │   ├── kubernetes/       # k3s / kubeadm
│   │   └── monitoring/       # Prometheus + Grafana
│   └── playbooks/
│       ├── provision.yml     # Post-terraform VM setup
│       └── configure.yml     # App-level config
├── scripts/
│   ├── create-template.sh    # Tạo cloud-init template
│   └── bootstrap-ceph.sh     # Init Ceph cluster
└── .github/workflows/
    └── infra.yml             # CI/CD pipeline
```

## Quick start

```bash
# 1. Copy và điền giá trị thực
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# 2. Init + plan
cd terraform
terraform init
terraform plan

# 3. Apply
terraform apply

# 4. Configure VMs
cd ../ansible
ansible-playbook -i inventory/proxmox.yml playbooks/provision.yml
```
