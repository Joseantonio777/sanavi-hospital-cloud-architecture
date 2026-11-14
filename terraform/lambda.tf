# ============================================================================
# Grupo Hospitalario SanaVI - Funciones Serverless AWS Lambda & Eventos
# Procesamiento de Citas, Alertas de Inventario y Reportes de Facturación
# ============================================================================

resource "aws_sns_topic" "sanavi_alerts" {
  name              = "sanavi-hospital-alerts-topic"
  kms_master_key_id = aws_kms_key.sanavi_hipaa_key.id
}

# 1. Función Lambda: Notificador de Citas Médicas
resource "aws_lambda_function" "appointment_notifier" {
  function_name = "sanavi-appointment-notifier"
  role          = "arn:aws:iam::486923200363:role/LabRole"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256
  filename      = "${path.module}/../serverless/appointment-notifier/function.zip"

  environment {
    variables = {
      CITAS_TABLE   = aws_dynamodb_table.sanavi_citas.name
      SNS_TOPIC_ARN = aws_sns_topic.sanavi_alerts.arn
    }
  }

  tracing_config {
    mode = "Active" # Trazabilidad distribuida en AWS X-Ray
  }
}

# 2. Función Lambda: Alerta de Quiebre de Stock en Inventario Médico
resource "aws_lambda_function" "inventory_alert" {
  function_name = "sanavi-inventory-alert"
  role          = "arn:aws:iam::486923200363:role/LabRole"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256
  filename      = "${path.module}/../serverless/inventory-alert/function.zip"

  environment {
    variables = {
      INVENTARIO_TABLE = aws_dynamodb_table.sanavi_inventario.name
      SNS_TOPIC_ARN    = aws_sns_topic.sanavi_alerts.arn
    }
  }

  tracing_config {
    mode = "Active"
  }
}

# Trigger de DynamoDB Streams hacia la función de alerta de inventario
resource "aws_lambda_event_source_mapping" "inventory_stream_trigger" {
  event_source_arn  = aws_dynamodb_table.sanavi_inventario.stream_arn
  function_name     = aws_lambda_function.inventory_alert.arn
  starting_position = "LATEST"
  batch_size        = 10
}

# 3. Función Lambda: Generador de Reportes Automáticos y Vencimiento de Facturas
resource "aws_lambda_function" "billing_report" {
  function_name = "sanavi-billing-report"
  role          = "arn:aws:iam::486923200363:role/LabRole"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256
  filename      = "${path.module}/../serverless/billing-report-generator/function.zip"

  environment {
    variables = {
      REPORTS_BUCKET = aws_s3_bucket.billing_reports.bucket
      KMS_KEY_ARN    = aws_kms_key.sanavi_hipaa_key.arn
      SNS_TOPIC_ARN  = aws_sns_topic.sanavi_alerts.arn
    }
  }

  tracing_config {
    mode = "Active"
  }
}

# Regla de Amazon EventBridge para generación programada de reportes
resource "aws_cloudwatch_event_rule" "daily_billing_check" {
  name                = "sanavi-daily-billing-expiration-check"
  description         = "Dispara diariamente la verificación de facturas por vencer y generación de reportes"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "billing_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_billing_check.name
  target_id = "SanaviBillingLambdaTarget"
  arn       = aws_lambda_function.billing_report.arn
}
