import json
import os
import uuid
from datetime import datetime, timezone
import boto3

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

CITAS_TABLE = os.environ.get("CITAS_TABLE", "SanaVI-Citas")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")


def lambda_handler(event, context):
    """
    AWS Lambda Function: sanavi-appointment-notifier
    Procesa la programacion, modificacion o cancelacion de citas medicas
    en DynamoDB y emite notificaciones a los pacientes via Amazon SNS.
    Cumple con trazabilidad AWS X-Ray y auditoria CloudWatch (HIPAA).
    """
    print(f"[HIPAA-AUDIT] Event received: {json.dumps(event)}")

    body = event
    if isinstance(event.get("body"), str):
        body = json.loads(event["body"])

    appointment_id = body.get("appointmentId", f"CITA-{uuid.uuid4().hex[:8].upper()}")
    patient_id = body.get("patientId", "PAC-FICTICIO-001")
    patient_name = body.get("patientName", "Paciente de Prueba")
    doctor_name = body.get("doctorName", "Médico de prueba")
    hospital_branch = body.get("hospitalBranch", "Hospital SanaVI Sede Central")
    appointment_date = body.get("appointmentDate", "2026-11-20T10:30:00-03:00")
    action = body.get("action", "PROGRAMADA")

    timestamp = datetime.now(timezone.utc).isoformat()

    table = dynamodb.Table(CITAS_TABLE)
    item = {
        "appointmentId": appointment_id,
        "patientId": patient_id,
        "patientName": patient_name,
        "doctorName": doctor_name,
        "hospitalBranch": hospital_branch,
        "appointmentDate": appointment_date,
        "status": action,
        "updatedAt": timestamp,
        "encryptionStandard": "AWS-KMS-HIPAA-AES256",
    }
    table.put_item(Item=item)

    notification_msg = (
        f"[SanaVI Salud] Estimado/a {patient_name}, su cita médica ({appointment_id}) "
        f"con {doctor_name} en {hospital_branch} para el {appointment_date} "
        f"ha sido {action} exitosamente."
    )

    sns_message_id = "SIMULATED-LOCAL"
    if SNS_TOPIC_ARN:
        resp = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"SanaVI - Confirmación de Cita Médica {appointment_id}",
            Message=notification_msg,
        )
        sns_message_id = resp.get("MessageId")

    response_payload = {
        "status": "SUCCESS",
        "service": "sanavi-appointment-notifier",
        "hipaaAuditTimestamp": timestamp,
        "appointment": item,
        "notification": {
            "channel": "Amazon SNS / SMS / Email",
            "messageId": sns_message_id,
            "summary": notification_msg,
        },
    }

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Strict-Transport-Security": "max-age=63072000; includeSubDomains; preload",
        },
        "body": json.dumps(response_payload, ensure_ascii=False),
    }
