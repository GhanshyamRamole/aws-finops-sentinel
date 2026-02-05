import boto3
import os
import time
from boto3.dynamodb.conditions import Attr

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
ec2 = boto3.client('ec2', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    print("🧹 Starting Snapshot Cleaner...")
    current_time = int(time.time())

    response = table.scan(
        FilterExpression=Attr('DeleteAt').lt(current_time) & 
                         Attr('Status').eq('GracePeriod') & 
                         Attr('ResourceType').eq('EBS_Snapshot')
    )

    for item in response.get('Items', []):
        resource_id = item['ResourceId']
        try:
            # Delete Snapshot
            ec2.delete_snapshot(SnapshotId=resource_id)
            
            # Update State
            table.update_item(
                Key={'ResourceId': resource_id},
                UpdateExpression="set #s = :s, DeletedAt = :d",
                ExpressionAttributeNames={'#s': 'Status'},
                ExpressionAttributeValues={':s': 'Deleted', ':d': int(time.time())}
            )
            print(f"✅ Deleted Snapshot {resource_id}")

        except Exception as e:
            if "InvalidSnapshot.NotFound" in str(e):
                 table.delete_item(Key={'ResourceId': resource_id})
            print(f"❌ Error: {e}")
