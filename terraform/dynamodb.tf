# ============================================================================
# Grupo Hospitalario SanaVI - Bases de Datos NoSQL Serverless Amazon DynamoDB
# Gestión de Citas Médicas y Gestión de Inventarios Médicos en Tiempo Real
# ============================================================================

resource "aws_dynamodb_table" "sanavi_citas" {
  name             = "SanaVI-Citas"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "appointmentId"
  range_key        = "patientId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "appointmentId"
    type = "S"
  }

  attribute {
    name = "patientId"
    type = "S"
  }

  # Encriptación en reposo con clave KMS dedicada (HIPAA)
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.sanavi_hipaa_key.arn
  }

  # Recuperación a un punto en el tiempo (PITR) contra borrado accidental
  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "sanavi_inventario" {
  name             = "SanaVI-Inventario"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "itemId"
  range_key        = "hospitalId"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "itemId"
    type = "S"
  }

  attribute {
    name = "hospitalId"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.sanavi_hipaa_key.arn
  }

  point_in_time_recovery {
    enabled = true
  }
}
