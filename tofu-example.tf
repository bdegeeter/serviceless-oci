terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "tls" {}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

output "private_key_pem" {
  description = "PEM-formatted private key"
  value       = tls_private_key.example.private_key_pem
}

output "public_key_openssh" {
  description = "OpenSSH-formatted public key"
  value       = tls_private_key.example.public_key_openssh
}
