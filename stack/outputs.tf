output "control-node-ip" {
  value = aws_instance.gdanca_control_node.public_ip
}

output "worker-node-ip" {
  value = aws_instance.gdanca_worker_node.public_ip
}