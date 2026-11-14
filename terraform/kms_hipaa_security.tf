# ============================================================================
# Grupo Hospitalario SanaVI - Seguridad y Cumplimiento Normativo HIPAA
# Encriptación AWS KMS AES-256, S3 Encriptado, Colas SQS Legacy + DLQ
# ============================================================================

resource "aws_kms_key" "sanavi_hipaa_key" {
  description             = "SanaVI Hospital Group - HIPAA AES-256 Master Key for PHI & Financial Data"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "sanavi_hipaa_key_alias" {
  name          = "alias/sanavi-hipaa-master-key"
  target_key_id = aws_kms_key.sanavi_hipaa_key.key_id
}

resource "aws_s3_bucket" "billing_reports" {
  bucket = "sanavi-hipaa-billing-reports-486923200363"
}

resource "aws_s3_bucket_public_access_block" "billing_reports_block" {
  bucket                  = aws_s3_bucket.billing_reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "billing_reports_kms" {
  bucket = aws_s3_bucket.billing_reports.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.sanavi_hipaa_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Cola Dead-Letter Queue (DLQ) para Tolerancia a Fallos en Integración Legacy HL7/FHIR
resource "aws_sqs_queue" "legacy_hl7_dlq" {
  name              = "sanavi-legacy-hl7-dlq"
  kms_master_key_id = aws_kms_alias.sanavi_hipaa_key_alias.name
}

resource "aws_sqs_queue" "legacy_hl7_queue" {
  name                       = "sanavi-legacy-hl7-integration-queue"
  visibility_timeout_seconds = 60
  kms_master_key_id          = aws_kms_alias.sanavi_hipaa_key_alias.name

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.legacy_hl7_dlq.arn
    maxReceiveCount     = 3
  })
}
