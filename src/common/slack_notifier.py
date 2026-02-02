import boto3
import os
import json
import urllib3
from datetime import datetime
from boto3.dynamodb.conditions import Attr

# Configuration
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
REGION = os.environ['AWS_REGION']

dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)
http = urllib3.PoolManager()

def lambda_handler(event, context):
    print("📢 Starting CloudSentinel Notifier...")
    
    # 1. Scan DynamoDB for items in 'GracePeriod'
    # In production, use a GSI (Global Secondary Index) for performance, 
    # but a Scan is fine for this portfolio scale.
    response = table.scan(
        FilterExpression=Attr('Status').eq('GracePeriod')
    )
    items = response.get('Items', [])
    
    if not items:
        print("✅ No items pending deletion.")
        return {"status": "No notifications needed"}

    # 2. Build the Slack Message Payload
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🚨 CloudSentinel: Resources Marked for Deletion"
            }
        },
        {
            "type": "divider"
        }
    ]

    current_time = datetime.now().timestamp()

    for item in items:
        resource_id = item['ResourceId']
        delete_at = int(item['DeleteAt'])
        waste_cost = item.get('EstimatedMonthlyWaste', '0.00')
        
        # Calculate days remaining
        days_left = int((delete_at - current_time) / 86400)
        
        # Color urgency (Emoji)
        icon = "🟢" if days_left > 3 else "🔴"
        
        row = {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*{icon} ID:* `{resource_id}`"},
                {"type": "mrkdwn", "text": f"*Est. Waste:* ${waste_cost}/mo"},
                {"type": "mrkdwn", "text": f"*Action:* Delete in {days_left} days"}
            ]
        }
        blocks.append(row)

    # 3. Send to Slack
    msg = {
        "blocks": blocks
    }
    
    encoded_msg = json.dumps(msg).encode('utf-8')
    resp = http.request('POST', SLACK_WEBHOOK_URL, body=encoded_msg)
    
    print(f"📨 Notification sent. Status Code: {resp.status}")
    return {"status": "Notification Sent", "count": len(items)}
