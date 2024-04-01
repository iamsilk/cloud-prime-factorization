# Generated private key for admin to SSH into all VMs
# Export the private/public keys to your local machine with:
/*
terraform output -raw admin_private_key > ~/.ssh/cado
terraform output -raw admin_public_key > ~/.ssh/cado.pub
chmod 600 ~/.ssh/cado
chmod 644 ~/.ssh/cado.pub
*/
output "admin_private_key" {
  sensitive = true
  value     = tls_private_key.admin_key.private_key_openssh
}

# Generated public key for admin
output "admin_public_key" {
  value = tls_private_key.admin_key.public_key_openssh
}

# IP of master service
output "master_ip" {
  value = digitalocean_droplet.master.ipv4_address
}

output "worker_ips" {
  value = digitalocean_droplet.worker.*.ipv4_address
}

output "worker_ips_private" {
  value = digitalocean_droplet.worker.*.ipv4_address_private
}

output "master_command" {
  value = <<EOL
./cado-nfs.py ${var.number_to_factor} \
    server.address=${digitalocean_droplet.master.ipv4_address_private} \
    tasks.workdir=/tmp/c100 \
    slaves.hostnames=${join(",", digitalocean_droplet.worker.*.ipv4_address_private)} \
    slaves.scriptpath=/root/cado-nfs/ \
    --slaves 24 \
    --client-threads 2
EOL
}