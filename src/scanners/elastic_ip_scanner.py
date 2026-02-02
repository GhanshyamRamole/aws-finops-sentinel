import boto3
import os
from src.common.dynamo_helper import DynamoHelper

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
ec2 = boto3.client('ec2', region_name=REGION)
db = DynamoHelper(DYNAMODB_TABLE, REGION)

def lambda_handler(event, context):
    print("🚀 Scanning for Unused Elastic IPs...")
    
    # Filter for IPs with no 'AssociationId'
    addresses = ec2.describe_addresses()['Addresses']
    
    for ip in addresses:
        if 'AssociationId' not in ip:
            allocation_id = ip['AllocationId']
            public_ip = ip['PublicIp']
            # EIP cost is roughly $3.65/mo if unused
            
            tags = {t['Key']: t['Value'] for t in ip.get('Tags', [])}
            if tags.get('CloudSentinel') == 'Ignore': continue

            db.register_resource(
                resource_id=allocation_id,
                resource_type='Elastic_IP',
                cost=3.65,
                tags=tags
            )

    return {"status": "EIP Scan Complete"}
