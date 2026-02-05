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
    print("🧹 Starting Elastic IP Cleaner...")
    current_time = int(time.time())

    # Filter ONLY for Elastic_IP
    response = table.scan(
        FilterExpression=Attr('DeleteAt').lt(current_time) & 
                         Attr('Status').eq('GracePeriod') & 
                         Attr('ResourceType').eq('Elastic_IP')
    )

    for item in response.get('Items', []):
        resource_id = item['ResourceId']
        try:
            # 1. Safety Check: Is it associated?
            addr = ec2.describe_addresses(AllocationIds=[resource_id])
            if 'AssociationId' in addr['Addresses'][0]:
                print(f"🛑 {resource_id} is in use. Marking Rescued.")
                table.update_item(Key={'ResourceId': resource_id}, UpdateExpression="set #s = :s", ExpressionAttributeNames={'#s': 'Status'}, ExpressionAttributeValues={':s': 'Rescued'})
                continue

            # 2. Release
            ec2.release_address(AllocationId=resource_id)
            
            # 3. Update State
            table.update_item(Key={'ResourceId': resource_id}, UpdateExpression="set #s = :s, DeletedAt = :d", ExpressionAttributeNames={'#s': 'Status'}, ExpressionAttributeValues={':s': 'Deleted', ':d': int(time.time())})
            print(f"✅ Released IP {resource_id}")

        except Exception as e:
            print(f"❌ Error: {e}")
