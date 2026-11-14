# ============================================================================
# Grupo Hospitalario SanaVI - Base de Datos Relacional Amazon RDS PostgreSQL
# Almacenamiento ACID para Historia Clínica Electrónica (HCE) y Facturación
# ============================================================================

resource "aws_db_subnet_group" "sanavi_rds_subnet_group" {
  name       = "sanavi-rds-isolated-subnet-group"
  subnet_ids = [aws_subnet.isolated_db_a.id, aws_subnet.isolated_db_b.id]
  tags       = { Name = "SanaVI Isolated DB Subnet Group" }
}

resource "aws_db_instance" "sanavi_hce_billing_db" {
  identifier              = "sanavi-hce-billing-db"
  engine                  = "postgres"
  engine_version          = "18.3"
  instance_class          = "db.t3.medium"
  allocated_storage       = 100
  max_allocated_storage   = 500
  storage_type            = "gp3"
  db_name                 = "sanavi_clinical_db"
  username                = "sanavi_admin"
  password                = var.db_master_password
  db_subnet_group_name    = aws_db_subnet_group.sanavi_rds_subnet_group.name
  multi_az                = true
  publicly_accessible     = false

  # Seguridad y Cumplimiento HIPAA en Reposo
  storage_encrypted = true
  kms_key_id        = aws_kms_key.sanavi_hipaa_key.arn

  # Backups automatizados y retención para recuperación ante desastres (DRP)
  backup_retention_period   = 35
  copy_tags_to_snapshot     = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "sanavi-hce-billing-final-snapshot"

  # Logs de auditoría PostgreSQL hacia CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
}

variable "db_master_password" {
  description = "Contraseña maestra de RDS inyectada en tiempo de despliegue vía AWS Secrets Manager o TF_VAR_db_master_password (sin valor por defecto en código)"
  type        = string
  sensitive   = true
}
