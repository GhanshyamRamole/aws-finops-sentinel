import boto3
import os
import time
from boto3.dynamodb.conditions import Attr

# Configuration
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']

ec2 = boto3.client('ec2', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    print("🧹 Starting CloudSentinel Cleaner...")
    
    current_time = int(time.time())

    # 1. Find items past their deadline
    # We scan for items where DeleteAt < Now AND Status is still 'GracePeriod'
    response = table.scan(
        FilterExpression=Attr('DeleteAt').lt(current_time) & Attr('Status').eq('GracePeriod')
    )
    expired_items = response.get('Items', [])
    
    print(f"found {len(expired_items)} items ready for deletion.")

    for item in expired_items:
        resource_id = item['ResourceId']
        resource_type = item['ResourceType']
        
        try:
            # 2. JUST-IN-TIME SAFETY CHECK
            # Before deleting, verify the resource is STILL unused.
            # If a user attached the volume yesterday, we must NOT delete it.
            if resource_type == 'EBS_Volume':
                vol_desc = ec2.describe_volumes(VolumeIds=[resource_id])
                current_state = vol_desc['Volumes'][0]['State']
                
                if current_state != 'available':
                    print(f"🛑 ABORT: {resource_id} is now '{current_state}'. User saved it!")
                    # Update DB to reflect it was saved
                    table.update_item(
                        Key={'ResourceId': resource_id},
                        UpdateExpression="set #s = :s",
                        ExpressionAttributeNames={'#s': 'Status'},
                        ExpressionAttributeValues={':s': 'Rescued'}
                    )
                    continue

            # 3. Execute Deletion
            print(f"🗑️ Deleting {resource_id}...")
            
            if resource_type == 'EBS_Volume':
                ec2.delete_volume(VolumeId=resource_id)
            
            # 4. Update State to 'Deleted' (so we don't process it again)
            table.update_item(
                Key={'ResourceId': resource_id},
                UpdateExpression="set #s = :s, DeletedAt = :d",
                ExpressionAttributeNames={'#s': 'Status'},
                ExpressionAttributeValues={
                    ':s': 'Deleted',
                    ':d': int(time.time())
                }
            )
            print(f"✅ {resource_id} successfully deleted.")

        except ec2.exceptions.ClientError as e:
            if 'InvalidVolume.NotFound' in str(e):
                print(f"⚠️ {resource_id} already gone.")
                table.delete_item(Key={'ResourceId': resource_id})
            else:
                print(f"❌ Error deleting {resource_id}: {e}")

    return {"status": "Cleanup Complete"}
