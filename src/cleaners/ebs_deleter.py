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
    print("🧹 Starting EBS Cleaner...")
    current_time = int(time.time())

    # Filter ONLY for EBS_Volume
    response = table.scan(
        FilterExpression=Attr('DeleteAt').lt(current_time) & 
                         Attr('Status').eq('GracePeriod') & 
                         Attr('ResourceType').eq('EBS_Volume')
    )
    
    for item in response.get('Items', []):
        resource_id = item['ResourceId']
        try:
            # 1. Safety Check: Is it attached?
            vol = ec2.describe_volumes(VolumeIds=[resource_id])
            if vol['Volumes'][0]['State'] != 'available':
                print(f"🛑 {resource_id} is attached. Marking Rescued.")
                table.update_item(Key={'ResourceId': resource_id}, UpdateExpression="set #s = :s", ExpressionAttributeNames={'#s': 'Status'}, ExpressionAttributeValues={':s': 'Rescued'})
                continue

            # 2. Delete
            ec2.delete_volume(VolumeId=resource_id)
            
            # 3. Update State
            table.update_item(Key={'ResourceId': resource_id}, UpdateExpression="set #s = :s, DeletedAt = :d", ExpressionAttributeNames={'#s': 'Status'}, ExpressionAttributeValues={':s': 'Deleted', ':d': int(time.time())})
            print(f"✅ Deleted volume {resource_id}")

        except Exception as e:
            print(f"❌ Error: {e}")
