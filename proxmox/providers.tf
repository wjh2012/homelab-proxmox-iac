# 인증: 환경변수 PROXMOX_VE_USERNAME / PROXMOX_VE_PASSWORD 사용
# SSH(스니펫 업로드)도 같은 계정/비밀번호를 그대로 사용
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true # 자체 서명 인증서

  ssh {
    agent = false

    dynamic "node" {
      for_each = var.nodes
      content {
        name    = node.key
        address = node.value
      }
    }
  }
}
