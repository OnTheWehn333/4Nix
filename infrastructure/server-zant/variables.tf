variable "enable_truenas_pool" {
  description = "Manage the validated Incus TrueNAS storage pool; set false only as a temporary safety gate on a fresh replacement host."
  type        = bool
  default     = true
}

variable "default_root_disk_size" {
  description = "Default Incus root disk size once the TrueNAS pool is enabled."
  type        = string
  default     = "256GiB"
}

variable "enable_server_gohdan" {
  description = "Manage the server-gohdan identity VM and its bootstrap image."
  type        = bool
  default     = true
}

variable "server_gohdan_image_directory" {
  description = "Directory containing disk.qcow2 and metadata.tar.xz from the server-gohdan-incus-image flake output."
  type        = string
  default     = "../../result-server-gohdan"
}

variable "server_gohdan_ipv4_address" {
  description = "Static IPv4 address for server-gohdan on incusbr0."
  type        = string
  default     = "10.100.0.10"
}

variable "server_gohdan_cpu_count" {
  description = "Virtual CPU count for server-gohdan."
  type        = number
  default     = 4
}

variable "server_gohdan_memory" {
  description = "Memory limit for server-gohdan."
  type        = string
  default     = "8GiB"
}

variable "enable_server_fi" {
  description = "Manage server-fi after building its image."
  type        = bool
  default     = true
}

variable "server_fi_image_directory" {
  description = "Hylia-local directory containing disk.qcow2 and metadata.tar.xz from server-fi-incus-image."
  type        = string
  default     = "../../result-server-fi"
}

variable "server_fi_ipv4_address" {
  description = "Static IPv4 address for server-fi on incusbr0."
  type        = string
  default     = "10.100.0.30"
}

variable "server_fi_cpu_count" {
  description = "Virtual CPU count shared by agents on server-fi."
  type        = number
  default     = 4
}

variable "server_fi_memory" {
  description = "Memory limit shared by agents on server-fi."
  type        = string
  default     = "8GiB"
}
