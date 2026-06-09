output "monitoring_instance_ip" {
  description = "Public IP of the monitoring EC2 instance"
  value       = aws_instance.monitoring.public_ip
}

output "honeypot_instance_ip" {
  description = "Public IP of the honeypot EC2 instance"
  value       = aws_instance.honeypot.public_ip
}

output "cloudtrail_bucket" {
  description = "S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
