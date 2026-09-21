terraform {
  required_version = ">= 1.10.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "~> 1.1"
    }
  }
}

# Hylia is the infrastructure control workstation. The provider uses the
# existing TLS-authenticated `zant` remote from ~/.config/incus/config.yml.
provider "incus" {
  default_remote = "zant"
}
