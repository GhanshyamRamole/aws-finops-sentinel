import boto3
import os
from common.dynamo_helper import DynamoHelper

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
logs = boto3.client('logs', region_name=REGION)
db = DynamoHelper(DYNAMODB_TABLE, REGION)

def lambda_handler(event, context):
    print("🚀 Scanning for Infinite Log Retention...")
    
    paginator = logs.get_paginator('describe_log_groups')
    
    for page in paginator.paginate():
        for group in page['logGroups']:
            name = group['logGroupName']
            stored_bytes = group.get('storedBytes', 0)
            
            # Check if 'retentionInDays' is MISSING (means Infinite)
            if 'retentionInDays' not in group:
                print(f"📜 Found infinite logs: {name}")
                
                # Cost: $0.03 per GB to store
                size_gb = stored_bytes / (1024 ** 3)
                est_cost = size_gb * 0.03
                
                # We use Log Group Name as ID
                # Note: CloudWatch Tags are fetched differently, skipping for simplicity here
                db.register_resource(
                    resource_id=name,
                    resource_type='Log_Group',
                    cost=est_cost,
                    tags={} 
                )

    return {"status": "Log Scan Complete"}
