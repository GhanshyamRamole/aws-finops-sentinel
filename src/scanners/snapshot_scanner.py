import boto3
import os
import datetime
from src.common.dynamo_helper import DynamoHelper

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
ec2 = boto3.client('ec2', region_name=REGION)
db = DynamoHelper(DYNAMODB_TABLE, REGION)

def lambda_handler(event, context):
    print("🚀 Scanning for Old EBS Snapshots...")
    
    # Get snapshots owned by self (ignore public ones)
    snapshots = ec2.describe_snapshots(OwnerIds=['self'])['Snapshots']
    current_time = datetime.datetime.now(datetime.timezone.utc)
    
    for snap in snapshots:
        snap_id = snap['SnapshotId']
        start_time = snap['StartTime']
        volume_size = snap['VolumeSize']
        
        # Calculate Age
        age = (current_time - start_time).days
        
        # Logic: Older than 30 days
        if age > 30:
            print(f"📸 Found old snapshot: {snap_id} ({age} days old)")
            
            # Simple Cost: Standard snapshot is ~$0.05 per GB/month
            est_cost = volume_size * 0.05
            
            tags = {t['Key']: t['Value'] for t in snap.get('Tags', [])}
            
            db.register_resource(
                resource_id=snap_id,
                resource_type='EBS_Snapshot',
                cost=est_cost,
                tags=tags
            )

    return {"status": "Snapshot Scan Complete"}
