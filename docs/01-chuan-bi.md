# 01 — Chuẩn bị (làm 1 lần)

> Môi trường: **Ubuntu Linux** (máy bạn hoặc 1 VM/LXC "control node" — xem [07-kien-truc-trien-khai.md](07-kien-truc-trien-khai.md)).
> Sau bước này bạn sẽ có: công cụ đã cài, 1 API token, 1 SSH key, và 1 cloud-init template trên Proxmox.

## 1. Cài công cụ trên Ubuntu

```bash
sudo apt update
sudo apt install -y git curl gnupg software-properties-common python3-pip

# --- Terraform (repo chính thức HashiCorp) ---
wget -O - https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# --- Ansible + collections ---
sudo apt install -y ansible
ansible-galaxy collection install community.general ansible.posix

# --- (tùy chọn) kubectl, helm để quản k3s sau này ---
sudo snap install kubectl --classic
sudo snap install helm --classic
```

Kiểm tra:

```bash
terraform version      # >= 1.7
ansible --version
```

> 💡 Cài thẳng trên Ubuntu, không cần WSL. Nếu chạy trên control node dùng chung (nhiều người), xem [07-kien-truc-trien-khai.md](07-kien-truc-trien-khai.md).

## 2. Tạo SSH key (nếu chưa có)

```bash
ssh-keygen -t ed25519 -C "proxmox-iac"
# Enter hết. Key nằm ở ~/.ssh/id_ed25519 (private) và id_ed25519.pub (public)
cat ~/.ssh/id_ed25519.pub        # COPY nội dung này -> dán vào terraform.tfvars
```

Key **public** được cloud-init nhét vào VM → bạn SSH vào VM bằng key **private**.

## 3. Tạo API token trên Proxmox

Terraform & Ansible nói chuyện với Proxmox qua **API token** (không dùng mật khẩu).

**3a. Tạo user + token (trên PVE UI):**
`Datacenter → Permissions → Users` → tạo user `terraform@pve`.
`Datacenter → Permissions → API Tokens` → Add → user `terraform@pve`, Token ID `tf-token`.
→ **Copy ngay Secret** (chỉ hiện 1 lần!). Token đầy đủ có dạng:

```
terraform@pve!tf-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**3b. Cấp quyền** (cho token tạo/sửa/xóa VM). Nhanh nhất (lab) — gán role `PVEAdmin` ở path `/`:

`Datacenter → Permissions → Add → API Token Permission`:
- Path: `/`
- API Token: `terraform@pve!tf-token`
- Role: `PVEAdmin`
- ✅ Propagate

> 🔒 Production nên tạo role hẹp hơn (chỉ VM/Datastore/SDN) thay vì PVEAdmin.

**3c. Token cho Ansible** (dùng cho dynamic inventory — chỉ cần đọc): tạo thêm token `ansible@pve!ansible-token` với role `PVEAuditor` (read-only) ở path `/`.

> ⚠️ **Bật API token theo realm:** nếu token báo 401, kiểm tra user dùng realm `pve` (Proxmox VE authentication), không phải `pam`.

## 4. Tạo cloud-init template (trên 1 PVE node)

Terraform **clone** VM từ 1 template có sẵn. Tạo template bằng script kèm theo:

```bash
# SSH vào 1 node Proxmox (hoặc dùng Shell trong web UI), rồi:
bash scripts/create-template.sh
```

Script này tải Ubuntu 24.04 cloud image, tạo VM ID **9000**, cấu hình cloud-init, rồi convert thành template.

> 📌 Template chỉ cần ở **1 node**. Nếu storage là **local-lvm** (cục bộ từng node), template nằm ở node nào thì VM clone từ nó cũng tạo nhanh nhất ở node đó. Khi đã có **Ceph** (storage dùng chung), clone được sang mọi node thoải mái. Với 9 node + local-lvm, cân nhắc tạo template ở vài node, hoặc chuyển template sang shared storage.

## 5. Chuẩn bị file bí mật (KHÔNG commit)

```bash
# Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars   # rồi điền giá trị thật

# Ansible vault (chứa secret như token, mật khẩu Grafana)
cd ../ansible/group_vars
cp vault.yml.example vault.yml
# Điền giá trị thật rồi mã hóa:
ansible-vault encrypt vault.yml
echo "mật-khẩu-vault-của-bạn" > ~/.vault_pass && chmod 600 ~/.vault_pass
```

Cả `terraform.tfvars` và `vault.yml` đã nằm trong `.gitignore`.

➡️ Tiếp theo: [02-terraform-co-ban.md](02-terraform-co-ban.md) — tạo VM đầu tiên.
