import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

TABLE_NAME = os.environ["TABLE_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]


def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    table = dynamodb.Table(TABLE_NAME)

    for record in event.get("Records", []):
        try:
            body = json.loads(record["body"])

            request_id = body["request_id"]
            name = body.get("name", "User")
            email = body["email"]
            portfolio_url = body["portfolio_url"]

            existing_item = table.get_item(Key={"request_id": request_id})
            item = existing_item.get("Item", {})

            if item.get("status") == "PROCESSED":
                print(f"Duplicate message ignored for request_id: {request_id}")
                continue

            table.update_item(
                Key={"request_id": request_id},
                UpdateExpression="SET #status = :status",
                ExpressionAttributeNames={
                    "#status": "status"
                },
                ExpressionAttributeValues={
                    ":status": "PROCESSED"
                }
            )

            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject="Portfolio Review Update",
                Message=json.dumps({
                    "message": "Review processed successfully",
                    "request_id": request_id,
                    "name": name,
                    "email": email,
                    "portfolio_url": portfolio_url,
                    "status": "PROCESSED"
                })
            )

            print(f"Processed request_id: {request_id}")

        except ClientError as e:
            print(f"AWS client error: {str(e)}")
            raise
        except Exception as e:
            print(f"Processing error: {str(e)}")
            raise

    return {
        "statusCode": 200,
        "body": json.dumps("Processed successfully")
    }