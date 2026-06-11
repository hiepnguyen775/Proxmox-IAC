# 06 — Vận hành hằng ngày (Day-2)

> Các thao tác lặp lại sau khi cụm đã chạy.

## 1. Thêm 1 VM mới

1. Thêm khối vào `vm_definitions` trong `terraform.tfvars` (chọn `vm_id`, `node`, `ip_address`, `tags` chưa trùng).
2. `terraform plan` → đảm bảo chỉ `1 to add`.
3. `terraform apply`.
4. `cd ../ansible && ansible-playbook playbooks/provision.yml --limit <tên-vm>`
5. Nếu VM thuộc nhóm app: `ansible-playbook playbooks/configure.yml --limit <tên-vm>` (hoặc theo nhóm).

## 2. Thêm 1 worker Kubernetes

Chỉ cần tag `["k8s","k8s-worker","prod"]`. Sau `apply`:

```bash
ansible-playbook playbooks/provision.yml --limit k8s-worker-04
ansible-playbook playbooks/configure.yml --tags k8s --limit k8s-worker-04
kubectl get nodes        # worker mới Ready
```

## 3. Thêm 1 node Proxmox (lên dần tới 9+)

```bash
# Trên node mới (đã cài Proxmox), join cluster:
pvecm add <IP-node-primary>
```

Rồi: thêm vào `proxmox_nodes` (Terraform) và `NODE_DISKS` (nếu mở rộng Ceph — chạy lại phần OSD của `bootstrap-ceph.sh` cho node mới).

## 4. Cập nhật cấu hình OS hàng loạt

Sửa role tương ứng rồi chạy lại — Ansible idempotent nên an toàn:

```bash
ansible-playbook playbooks/provision.yml                 # tất cả
ansible-playbook playbooks/provision.yml --check --diff  # xem trước
```

## 5. Xóa tài nguyên an toàn

```bash
# Xóa 1 VM: xóa khối khỏi vm_definitions -> apply
# hoặc:
terraform destroy -target='module.vms["test-01"]'
```

> Trước khi `destroy`, **đọc kỹ** plan: đảm bảo chỉ xóa đúng thứ định xóa.
> VM bị lock không stop được: `qm stop <id> --skiplock 1` trên node, rồi destroy lại.

## 6. Backup & phục hồi state Terraform

State là tài sản quý nhất:

- Dùng **remote state** (xem [05-nang-cao.md](05-nang-cao.md)) → tự versioned trên MinIO/S3.
- Nếu còn local: backup `terraform.tfstate` định kỳ.
- Lỡ tay hỏng state? `terraform refresh` đồng bộ lại với thực tế; resource bị "mất khỏi state" có thể `terraform import` lại.

## 7. Kiểm tra sức khỏe nhanh

```bash
# Terraform có khớp thực tế không (không đổi gì)
terraform plan        # mong: "No changes"

# Ansible: tất cả host phản hồi?
ansible all -m ping

# Kubernetes
export KUBECONFIG=ansible/kubeconfig.yaml
kubectl get nodes
kubectl get pods -A

# Ceph (trên node)
ceph -s
```

## 8. Quy trình làm việc với Git

```bash
git checkout -b feature/them-worker
# sửa terraform.tfvars / role...
git add -A && git commit -m "Thêm k8s-worker-04"
git push -u origin feature/them-worker
# Mở Pull Request -> CI chạy terraform plan -> review -> merge -> CI apply
```

> Không bao giờ commit `terraform.tfvars`, `vault.yml`, `kubeconfig.yaml`, `*.tfstate` (đã .gitignore).

---

### Checklist sự cố nhanh
| Triệu chứng | Xem |
|---|---|
| `terraform apply` 401 / clone fail | [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) #2, #3 |
| VM không có IP | TROUBLESHOOTING #4 |
| `ansible-inventory` rỗng | TROUBLESHOOTING #5 |
| SSH refused | TROUBLESHOOTING #6 |
| Pod khác node không nói chuyện được | Kiểm tra UFW 8472/udp + `trusted_network` ([03](03-ansible-co-ban.md) mục 5) |
| Ceph OSD down | TROUBLESHOOTING #7 |
