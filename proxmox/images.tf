# local 스토리지는 노드별이므로 노드마다 이미지와 스니펫을 준비
resource "proxmox_download_file" "ubuntu_2404" {
  for_each = var.nodes

  node_name    = each.key
  datastore_id = "local"
  content_type = "import"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"

  # upstream 이미지가 갱신돼도 다시 받지 않음 (교체되면 VM이 재생성됨)
  overwrite = false
}

resource "proxmox_virtual_environment_file" "vendor_data" {
  for_each = var.nodes

  node_name    = each.key
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "vendor-data.yaml"
    data      = file("${path.module}/cloud-init/vendor-data.yaml")
  }
}
