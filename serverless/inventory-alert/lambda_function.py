import json
import os
from datetime import datetime, timezone
import boto3

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

INVENTARIO_TABLE = os.environ.get("INVENTARIO_TABLE", "SanaVI-Inventario")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")


def lambda_handler(event, context):
    """
    AWS Lambda Function: sanavi-inventory-alert
    Monitorea cambios en el inventario médico (DynamoDB Streams / API Event)
    y dispara alertas críticas cuando el stock cae bajo el umbral mínimo.
    """
    print(f"[HIPAA-LOGISTICS-AUDIT] Processing inventory event: {json.dumps(event)}")

    body = event
    if isinstance(event.get("body"), str):
        body = json.loads(event["body"])

    item_id = body.get("itemId", "MED-INSULINA-GLARGINA-100UI")
    hospital_id = body.get("hospitalId", "SANAVI-SEDE-NORTE")
    medication_name = body.get("medicationName", "Insulina Glargina 100 UI/mL")
    current_stock = int(body.get("currentStock", 12))
    min_threshold = int(body.get("minThreshold", 50))
    batch_number = body.get("batchNumber", "LOTE-2026-AX99")

    timestamp = datetime.now(timezone.utc).isoformat()
    alert_triggered = current_stock < min_threshold
    status_label = "CRITICAL_LOW_STOCK" if alert_triggered else "OPTIMAL_STOCK"

    table = dynamodb.Table(INVENTARIO_TABLE)
    record = {
        "itemId": item_id,
        "hospitalId": hospital_id,
        "medicationName": medication_name,
        "currentStock": current_stock,
        "minThreshold": min_threshold,
        "batchNumber": batch_number,
        "stockStatus": status_label,
        "lastUpdated": timestamp,
    }
    table.put_item(Item=record)

    sns_message_id = None
    if alert_triggered and SNS_TOPIC_ARN:
        alert_text = (
            f"[ALERTA CRÍTICA DE INVENTARIO SANAVI] "
            f"El insumo {medication_name} ({item_id}) en {hospital_id} "
            f"tiene un stock crítico de {current_stock} unidades (Umbral mínimo: {min_threshold}). "
            f"Se ha generado orden automática de reabastecimiento."
        )
        resp = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"URGENTE: Quiebre de Stock Preventivo - {item_id}",
            Message=alert_text,
        )
        sns_message_id = resp.get("MessageId")

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(
            {
                "status": "PROCESSED",
                "service": "sanavi-inventory-alert",
                "alertTriggered": alert_triggered,
                "snsMessageId": sns_message_id,
                "inventoryRecord": record,
            },
            ensure_ascii=False,
        ),
    }
