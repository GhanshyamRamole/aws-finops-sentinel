import boto3
import os
import time
from boto3.dynamodb.conditions import Attr

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
logs = boto3.client('logs', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    print("🧹 Starting Log Retention Fixer...")
    current_time = int(time.time())

    response = table.scan(
        FilterExpression=Attr('DeleteAt').lt(current_time) & 
                         Attr('Status').eq('GracePeriod') & 
                         Attr('ResourceType').eq('Log_Group')
    )

    for item in response.get('Items', []):
        resource_id = item['ResourceId'] # Log Group Name
        try:
            # FIX: Don't delete logs, just set retention to 30 days to stop the bleeding
            logs.put_retention_policy(
                logGroupName=resource_id,
                retentionInDays=30
            )
            
            table.update_item(
                Key={'ResourceId': resource_id},
                UpdateExpression="set #s = :s, DeletedAt = :d",
                ExpressionAttributeNames={'#s': 'Status'},
                ExpressionAttributeValues={':s': 'Remediated', ':d': int(time.time())}
            )
            print(f"✅ Fixed Retention for {resource_id}")

        except Exception as e:
            if "ResourceNotFoundException" in str(e):
                table.delete_item(Key={'ResourceId': resource_id})
            print(f"❌ Error: {e}")
