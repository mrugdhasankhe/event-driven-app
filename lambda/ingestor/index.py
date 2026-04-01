import json
import uuid
import os
import boto3
from urllib.parse import urlparse

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")

TABLE_NAME = os.environ["TABLE_NAME"]
QUEUE_URL = os.environ["QUEUE_URL"]


def is_valid_url(url):
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except Exception:
        return False


def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    body = json.loads(event.get("body", "{}"))

    name = body.get("name")
    email = body.get("email")
    portfolio_url = body.get("portfolio_url")

    if not name or not email or not portfolio_url:
        return {
            "statusCode": 400,
            "body": json.dumps({
                "message": "name, email and portfolio_url are required"
            })
        }

    if not is_valid_url(portfolio_url):
        return {
            "statusCode": 400,
            "body": json.dumps({
                "message": "portfolio_url must be a valid URL"
            })
        }

    request_id = str(uuid.uuid4())

    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            "request_id": request_id,
            "name": name,
            "email": email,
            "portfolio_url": portfolio_url,
            "status": "SUBMITTED"
        }
    )

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({
            "request_id": request_id,
            "name": name,
            "email": email,
            "portfolio_url": portfolio_url
        })
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Review request submitted successfully",
            "request_id": request_id,
            "status": "SUBMITTED"
        })
    }