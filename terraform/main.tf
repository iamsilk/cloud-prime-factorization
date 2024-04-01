terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Key for admin SSH
resource "tls_private_key" "admin_key" {
  algorithm = "ED25519"
}

resource "digitalocean_ssh_key" "admin" {
  name       = "Terraform Admin"
  public_key = tls_private_key.admin_key.public_key_openssh
}

# Key for master-to-worker SSH
resource "tls_private_key" "master_key" {
  algorithm = "ED25519"
}

resource "digitalocean_ssh_key" "master" {
  name       = "Terraform Master"
  public_key = tls_private_key.master_key.public_key_openssh
}

# Create master server
resource "digitalocean_droplet" "master" {
  name   = "cado-nfs-master"
  image  = "ubuntu-23-10-x64"
  region = var.region
  size   = "c-48"

  ssh_keys = [digitalocean_ssh_key.admin.fingerprint]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = tls_private_key.admin_key.private_key_openssh
  }

  provisioner "file" {
    content     = tls_private_key.master_key.public_key_openssh
    destination = "/root/.ssh/id_rsa.pub"
  }

  provisioner "file" {
    content     = tls_private_key.master_key.private_key_openssh
    destination = "/root/.ssh/id_rsa"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/id_rsa",
      "chmod 644 /root/.ssh/id_rsa.pub",
      "git clone https://gitlab.inria.fr/cado-nfs/cado-nfs/ /root/cado-nfs",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y cmake build-essential libgmp3-dev",
      # disable strict host key checking
      "echo 'Host *' >> /root/.ssh/config && echo '    StrictHostKeyChecking no' >> /root/.ssh/config && echo '    UserKnownHostsFile=/dev/null' >> /root/.ssh/config",
      "cd /root/cado-nfs && make",
    ]
  }
}

# Create worker servers
resource "digitalocean_droplet" "worker" {
  count  = 8
  name   = "cado-nfs-worker-${count.index + 1}"
  image  = "ubuntu-23-10-x64"
  region = var.region
  size   = "c-48"

  ssh_keys = [digitalocean_ssh_key.admin.fingerprint, digitalocean_ssh_key.master.fingerprint]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = tls_private_key.admin_key.private_key_openssh
  }

  provisioner "remote-exec" {
    inline = [
      "git clone https://gitlab.inria.fr/cado-nfs/cado-nfs/ /root/cado-nfs",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential"
    ]
  }
}