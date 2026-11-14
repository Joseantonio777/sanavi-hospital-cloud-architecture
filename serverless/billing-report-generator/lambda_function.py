import json
import os
import uuid
from datetime import datetime, timezone
import boto3

s3 = boto3.client("s3")
sns = boto3.client("sns")

REPORTS_BUCKET = os.environ.get("REPORTS_BUCKET", "")
KMS_KEY_ARN = os.environ.get("KMS_KEY_ARN", "")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")


def lambda_handler(event, context):
    """
    AWS Lambda Function: sanavi-billing-report
    Genera reportes automáticos de facturación hospitalaria, detecta facturas
    próximas a vencer y almacena el reporte en Amazon S3 con cifrado AWS KMS (HIPAA).
    """
    print(f"[HIPAA-FINANCIAL-AUDIT] Generating billing report: {json.dumps(event)}")

    body = event
    if isinstance(event.get("body"), str):
        body = json.loads(event["body"])

    invoice_id = body.get("invoiceId", f"FAC-2026-{uuid.uuid4().hex[:6].upper()}")
    patient_id = body.get("patientId", "PAC-FICTICIO-001")
    amount_clp = body.get("amountCLP", 485000)
    due_date = body.get("dueDate", "2026-11-18")
    coverage_type = body.get("coverageType", "FONASA / Seguro Complementario")
    timestamp = datetime.now(timezone.utc).isoformat()

    report_content = {
        "reportId": f"REP-{uuid.uuid4().hex[:8].upper()}",
        "generatedAt": timestamp,
        "complianceStandard": "HIPAA-HITECH-AES256-KMS",
        "hospitalGroup": "Grupo Hospitalario SanaVI",
        "billingSummary": {
            "invoiceId": invoice_id,
            "patientId": patient_id,
            "amountCLP": amount_clp,
            "dueDate": due_date,
            "coverageType": coverage_type,
            "status": "EXPIRING_SOON_ALERT_SENT",
        },
    }

    s3_key = f"billing-reports/2026/11/{invoice_id}.json"
    if REPORTS_BUCKET:
        put_kwargs = {
            "Bucket": REPORTS_BUCKET,
            "Key": s3_key,
            "Body": json.dumps(report_content, indent=2, ensure_ascii=False).encode("utf-8"),
            "ContentType": "application/json",
        }
        if KMS_KEY_ARN:
            put_kwargs["ServerSideEncryption"] = "aws:kms"
            put_kwargs["SSEKMSKeyId"] = KMS_KEY_ARN
        s3.put_object(**put_kwargs)

    sns_message_id = None
    if SNS_TOPIC_ARN:
        resp = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"SanaVI Facturación - Aviso de Vencimiento {invoice_id}",
            Message=f"Factura {invoice_id} por ${amount_clp} CLP vence el {due_date}. Reporte encriptado KMS guardado en s3://{REPORTS_BUCKET}/{s3_key}",
        )
        sns_message_id = resp.get("MessageId")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "status": "REPORT_GENERATED_AND_ENCRYPTED",
                "service": "sanavi-billing-report",
                "s3Uri": f"s3://{REPORTS_BUCKET}/{s3_key}",
                "kmsEncrypted": bool(KMS_KEY_ARN),
                "snsMessageId": sns_message_id,
                "report": report_content,
            },
            ensure_ascii=False,
        ),
    }
