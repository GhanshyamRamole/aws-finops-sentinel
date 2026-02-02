import boto3
import os
import time
import json
import urllib.request
from boto3.dynamodb.conditions import Attr

# Configuration
SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']

dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    print("📢 Starting CloudSentinel Notifier...")
    
    current_time = int(time.time())
    
    # Scan for all items in 'GracePeriod'
    response = table.scan(
        FilterExpression=Attr('Status').eq('GracePeriod')
    )
    items = response.get('Items', [])
    
    if not items:
        print("✅ No waste found. Skipping Slack alert.")
        return {"status": "No Waste Found"}

    # Calculate Total Waste
    total_waste = sum(float(i.get('EstimatedMonthlyWaste', 0)) for i in items)
    
    # Build Slack Block Message
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"🚨 CloudSentinel Report: ${total_waste:.2f}/mo Potential Savings"
            }
        },
        {"type": "divider"}
    ]

    for item in items:
        resource_id = item['ResourceId']
        resource_type = item.get('ResourceType', 'Resource')
        delete_at = int(item['DeleteAt'])
        cost = float(item.get('EstimatedMonthlyWaste', 0))
        
        # Calculate Time Left
        days_left = int((delete_at - current_time) / 86400)
        
        # --- ICON LOGIC ---
        if resource_type == 'EBS_Volume':
            type_icon = "💾"
        elif resource_type == 'Elastic_IP':
            type_icon = "🌐"
        elif resource_type == 'EC2_Idle':
            type_icon = "💤"
        elif resource_type == 'EBS_Snapshot':
            type_icon = "📸"
        elif resource_type == 'Log_Group':
            type_icon = "📜"
        elif resource_type == 'Orphaned_LB':
            type_icon = "⚖️"
        else:
            type_icon = "📦"

        # Urgency Indicator
        urgency_icon = "🟢" if days_left > 3 else "🔴"
        
        row = {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*{type_icon} {resource_type}*\n`{resource_id}`"},
                {"type": "mrkdwn", "text": f"*Waste:* ${cost:.2f}/mo\n*{urgency_icon} Action:* Cleanup in {days_left} days"}
            ]
        }
        blocks.append(row)

    # Send to Slack
    payload = {"blocks": blocks}
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL, 
        data=json.dumps(payload).encode('utf-8'), 
        headers={'Content-Type': 'application/json'}
    )
    try:
        urllib.request.urlopen(req)
        print("✅ Slack notification sent.")
    except Exception as e:
        print(f"❌ Failed to send Slack alert: {e}")

    return {"status": "Notification Sent"}
