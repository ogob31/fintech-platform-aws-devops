data "aws_region" "current" {}

data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# SG: controller
resource "aws_security_group" "controller" {
  name        = "${var.name}-jenkins-controller-sg"
  description = "Jenkins controller SG (private)"
  vpc_id      = var.vpc_id

  # allow agent to connect to controller (JNLP 50000) + UI 8080 inside VPC only
  ingress {
    description     = "Jenkins UI from agent SG (optional) / internal"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.agent.id]
  }

  ingress {
    description     = "JNLP from agent"
    from_port       = 50000
    to_port         = 50000
    protocol        = "tcp"
    security_groups = [aws_security_group.agent.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG: agent
resource "aws_security_group" "agent" {
  name        = "${var.name}-jenkins-agent-sg"
  description = "Jenkins agent SG (private)"
  vpc_id      = var.vpc_id

  # agent does not need inbound from internet; only internal optional
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM role for EC2 instances: SSM + ECR/ECS/Logs (controller needs deploy perms; agent needs ECR push)
resource "aws_iam_role" "ec2" {
  name = "${var.name}-jenkins-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Minimal “CI deploy” policy (tighten later)
resource "aws_iam_role_policy" "ci_deploy" {
  name = "${var.name}-jenkins-ci-deploy"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # ECR push/pull
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ],
        Resource = "*"
      },
      # ECS deploy
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeClusters",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ],
        Resource = "*"
      },
      # CloudWatch logs (optional)
      {
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-jenkins-ec2-profile"
  role = aws_iam_role.ec2.name
}

locals {
  controller_userdata = <<-EOFU
    #!/bin/bash
    set -eux

    yum update -y
    amazon-linux-extras install java-openjdk11 -y
    yum install -y git docker jq
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # Install Jenkins
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    yum install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    yum install -y unzip
    unzip -q awscliv2.zip
    ./aws/install || true

    # Allow Jenkins to use Docker
    usermod -aG docker jenkins
    systemctl restart jenkins

    # Create a note file for first login
    echo "Jenkins initial admin password:" > /home/ec2-user/jenkins-init.txt
    cat /var/lib/jenkins/secrets/initialAdminPassword >> /home/ec2-user/jenkins-init.txt
    chown ec2-user:ec2-user /home/ec2-user/jenkins-init.txt
  EOFU

  agent_userdata = <<-EOFU
    #!/bin/bash
    set -eux

    yum update -y
    amazon-linux-extras install java-openjdk11 -y
    yum install -y git docker jq
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    yum install -y unzip
    unzip -q awscliv2.zip
    ./aws/install || true

    mkdir -p /opt/jenkins
    chown -R ec2-user:ec2-user /opt/jenkins
  EOFU
}

resource "aws_instance" "controller" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_controller
  subnet_id                   = var.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.controller.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = false
  user_data                   = local.controller_userdata

  tags = { Name = "${var.name}-jenkins-controller" }
}

resource "aws_instance" "agent" {
  ami                         = data.aws_ami.al2.id
  instance_type               = var.instance_type_agent
  subnet_id                   = var.private_subnet_ids[1]
  vpc_security_group_ids      = [aws_security_group.agent.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = false
  user_data                   = local.agent_userdata

  tags = { Name = "${var.name}-jenkins-agent-1" }
}
