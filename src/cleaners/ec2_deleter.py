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
    print("🧹 Starting EC2 Idle Cleaner...")
    current_time = int(time.time())

    # Filter ONLY for EC2_Idle
    response = table.scan(
        FilterExpression=Attr('DeleteAt').lt(current_time) & 
                         Attr('Status').eq('GracePeriod') & 
                         Attr('ResourceType').eq('EC2_Idle')
    )

    for item in response.get('Items', []):
        resource_id = item['ResourceId']
        try:
            # 1. Safety Check: Is it already stopped?
            inst = ec2.describe_instances(InstanceIds=[resource_id])
            state = inst['Reservations'][0]['Instances'][0]['State']['Name']
            
            if state in ['terminated', 'shutting-down', 'stopped']:
                print(f"ℹ️ {resource_id} is already {state}.")
            else:
                # 2. Stop Instance
                ec2.stop_instances(InstanceIds=[resource_id])
                print(f"✅ Stopped instance {resource_id}")
            
            # 3. Update State
            table.update_item(Key={'ResourceId': resource_id}, UpdateExpression="set #s = :s, DeletedAt = :d", ExpressionAttributeNames={'#s': 'Status'}, ExpressionAttributeValues={':s': 'Remediated', ':d': int(time.time())})

        except Exception as e:
            print(f"❌ Error: {e}")
