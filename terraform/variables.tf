variable "aws_region" {
  description = "AWS region that contains the public subnet."
  type        = string
}

variable "subnet_id" {
  description = "ID of an existing public subnet with an IPv4 route to an internet gateway."
  type        = string
}

variable "ssh_access" {
  description = "Optional SSH access using an IPv4 /32 and an existing EC2 key pair in this region."
  type = object({
    cidr     = string
    key_name = string
  })
  default = null

  validation {
    condition = var.ssh_access == null ? true : (
      can(cidrnetmask(var.ssh_access.cidr)) &&
      endswith(var.ssh_access.cidr, "/32") &&
      trimspace(var.ssh_access.key_name) != ""
    )
    error_message = "SSH access requires a single IPv4 address in /32 CIDR format and a key pair name."
  }
}
