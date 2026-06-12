# ============================================================
#  Remote state backend — S3-compatible (MinIO trong cụm Proxmox)
# ============================================================
# Mặc định: state LOCAL (đủ để 1 mình thử). Khi làm nhóm / "thực chiến"
# PHẢI bật remote state để không mất state và CI/CD dùng chung 1 nguồn.
# Có thể trỏ vào MinIO chạy ngay trong cụm Proxmox (không cần AWS thật).
#
# Cách bật:
#   1. Dựng MinIO + tạo bucket (vd "terraform-state"). Xem docs/05-nang-cao.md.
#   2. export AWS_ACCESS_KEY_ID=...  AWS_SECRET_ACCESS_KEY=...   # key của MinIO
#   3. cp backend.hcl.example backend.hcl   # điền endpoint/bucket THẬT
#   4. terraform init -backend-config=backend.hcl -migrate-state

# terraform {
#   backend "s3" {}
# }
