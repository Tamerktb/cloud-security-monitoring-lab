# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
  }
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name        = "${var.environment}-public-subnet"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
  }
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group for EC2
resource "aws_security_group" "ec2" {
  name        = "${var.environment}-ec2-sg"
  description = "Security group for monitoring EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Wazuh agent registration"
    from_port   = 1515
    to_port     = 1515
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Wazuh agent communication"
    from_port   = 55000
    to_port     = 55000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-ec2-sg"
    Environment = var.environment
  }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "${var.environment}-cloudtrail-logs-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "${var.environment}-cloudtrail-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "${var.environment}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name        = "${var.environment}-trail"
    Environment = var.environment
  }
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = {
    Name        = "${var.environment}-flow-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc-flow-logs/${var.environment}"
  retention_in_days = 30

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.environment}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.environment}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# EC2 instance for monitoring (Wazuh server)
resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name        = "${var.environment}-monitoring"
    Environment = var.environment
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 instance for attack target (honeypot)
resource "aws_instance" "honeypot" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.honeypot.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io
              docker run -d --restart=always -p 22:2222 stingar/cowrie
              EOF

  tags = {
    Name        = "${var.environment}-honeypot"
    Environment = var.environment
  }
}

resource "aws_security_group" "honeypot" {
  name        = "${var.environment}-honeypot-sg"
  description = "Security group for honeypot (wide open)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All traffic - honeypot"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-honeypot-sg"
    Environment = var.environment
  }
}

# IAM role for EC2 to send logs
resource "aws_iam_role" "ec2_logs" {
  name = "${var.environment}-ec2-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_logs" {
  role       = aws_iam_role.ec2_logs.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_logs" {
  name = "${var.environment}-ec2-logs-profile"
  role = aws_iam_role.ec2_logs.name
}
