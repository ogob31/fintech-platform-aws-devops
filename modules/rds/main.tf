data "aws_ssm_parameter" "db_user" {
  name = var.ssm_username_param
}

data "aws_ssm_parameter" "db_pass" {
  name            = var.ssm_password_param
  with_decryption = true
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = "${var.name}-db-subnets"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = data.aws_ssm_parameter.db_user.value
  password = data.aws_ssm_parameter.db_pass.value

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]

  publicly_accessible = false
  multi_az            = false

  storage_encrypted        = true
  backup_retention_period  = 7
  deletion_protection      = false
  skip_final_snapshot      = true
  apply_immediately        = true

  tags = {
    Name = "${var.name}-postgres"
  }
}

output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}
