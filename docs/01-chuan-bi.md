# 01 — Chuẩn bị (làm 1 lần)

> Sau bước này bạn sẽ có: công cụ trên máy Windows, 1 API token, 1 SSH key, và 1 cloud-init template trên Proxmox.

## 1. Cài công cụ trên máy bạn (Windows)

Mở **PowerShell** và dùng `winget`:

```powershell
winget install HashiCorp.Terraform
winget install Git.Git
# Ansible chạy trên Linux là chính. Trên Windows nên dùng WSL2:
wsl --install -d Ubuntu
```

Sau đó **trong WSL (Ubuntu)** cài Ansible:

```bash
sudo apt update
sudo apt install -y python3-pip
python3 -m pip install --user ansible
ansible-galaxy collection install community.general ansible.posix
```

Kiểm tra:

```powershell
terraform version      # >= 1.7
```
```bash
ansible --version      # trong WSL
```

> 💡 **Vì sao Ansible nên chạy trong WSL?** Ansible dùng SSH và nhiều module Linux; chạy native trên Windows rất khó. WSL2 cho bạn 1 Ubuntu thật ngay trong Windows. Terraform thì chạy thẳng trên Windows hay WSL đều được — **chọn 1 chỗ** và làm việc nhất quán ở đó (khuyên: làm tất cả trong WSL cho đồng bộ).

## 2. Tạo SSH key (nếu chưa có)

Trong WSL:

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
