output "app_url" {
  description = "Public HTTP URL of the FastAPI application."
  value       = "http://${aws_instance.app.public_ip}:8080"
}

output "instance_id" {
  description = "EC2 instance ID for operations and troubleshooting."
  value       = aws_instance.app.id
}
