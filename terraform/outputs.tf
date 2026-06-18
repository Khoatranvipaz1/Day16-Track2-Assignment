output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "alb_dns_name" {
  value = aws_lb.ai_alb.dns_name
  description = "The DNS name of the ALB to access the inference endpoint"
}

output "endpoint_url" {
  value       = "CPU fallback mode: no vLLM endpoint is started. SSH to cpu_private_ip and run the LightGBM benchmark."
  description = "The CPU fallback path does not expose an OpenAI-compatible inference endpoint."
}

output "cpu_private_ip" {
  value = aws_instance.gpu_node.private_ip
}

output "gpu_private_ip" {
  value = aws_instance.gpu_node.private_ip
  description = "Legacy output name; this is the CPU benchmark node private IP in CPU fallback mode."
}
