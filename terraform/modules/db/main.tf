resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "this" {
  identifier                  = "${var.name}-mysql"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = var.instance_class
  allocated_storage           = 20
  db_name                     = "appdb"
  username                    = "admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [var.db_sg_id]
  publicly_accessible         = false
  multi_az                    = var.multi_az
  storage_encrypted           = true
  backup_retention_period     = 0
  skip_final_snapshot         = true
  deletion_protection         = false
  apply_immediately           = true
}
