output "master_public_ip" {
  description = "Public IP of K3s master node"
  value       = aws_instance.k3s_master.public_ip
}

output "master_private_ip" {
  description = "Private IP of K3s master node"
  value       = aws_instance.k3s_master.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of K3s worker nodes"
  value       = aws_instance.k3s_workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of K3s worker nodes"
  value       = aws_instance.k3s_workers[*].private_ip
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "ssh -i ~/.ssh/k3s-cluster ubuntu@${aws_instance.k3s_master.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

output "ssh_master_command" {
  description = "Command to SSH into master"
  value       = "ssh -i ~/.ssh/k3s-cluster ubuntu@${aws_instance.k3s_master.public_ip}"
}

