# ============================================================================
# Grupo Hospitalario SanaVI - Observabilidad, Monitoreo y Trazabilidad
# Amazon CloudWatch Logs, Alarmas de Rendimiento y AWS X-Ray Sampling Rules
# ============================================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/sanavi-hipaa-flow-logs"
  retention_in_days = 365 # Retención extendida para auditorías HIPAA
  kms_key_id        = aws_kms_key.sanavi_hipaa_key.arn
}

resource "aws_cloudwatch_log_group" "eks_application_logs" {
  name              = "/aws/eks/sanavi-eks-cluster/clinical-microservices"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.sanavi_hipaa_key.arn
}

resource "aws_xray_sampling_rule" "sanavi_clinical_tracing" {
  rule_name      = "SanaVI-HIPAA-Distributed-Tracing"
  priority       = 100
  version        = 1
  reservoir_size = 5
  fixed_rate     = 0.20
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"
}
