import boto3
import os
import time
from datetime import datetime, timedelta

# Configuration
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
GRACE_PERIOD_DAYS = 7
REGION = os.environ['AWS_REGION']

ec2 = boto3.client('ec2', region_name=REGION)
dynamodb = boto3.resource('dynamodb', region_name=REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    print("🚀 Starting CloudSentinel EBS Scanner...")
    
    # 1. Find Unattached Volumes
    # We filter for 'available' state which means not attached to any EC2
    response = ec2.describe_volumes(
        Filters=[{'Name': 'status', 'Values': ['available']}]
    )
    
    unused_volumes = response['Volumes']
    print(f"🔍 Found {len(unused_volumes)} unattached volumes.")

    for vol in unused_volumes:
        vol_id = vol['VolumeId']
        size_gb = vol['Size']
        # Simple cost estimation (gp3 approx $0.08/GB) - Adjust per region/type
        est_cost = size_gb * 0.08 
        
        # Check for Immunity Tags
        tags = {t['Key']: t['Value'] for t in vol.get('Tags', [])}
        if tags.get('CloudSentinel') == 'Ignore':
            print(f"🛡️ Skipping {vol_id} (Immunity Tag detected)")
            continue

        # 2. Check State in DynamoDB
        # We only want to add it if it's new. If it's already there, the timer is already ticking.
        # This prevents resetting the grace period every day.
        try:
            ddb_item = table.get_item(Key={'ResourceId': vol_id})
            
            if 'Item' not in ddb_item:
                # 3. Register New Offender
                deletion_date = int((datetime.now() + timedelta(days=GRACE_PERIOD_DAYS)).timestamp())
                
                table.put_item(
                    Item={
                        'ResourceId': vol_id,
                        'ResourceType': 'EBS_Volume',
                        'DetectedAt': int(time.time()),
                        'DeleteAt': deletion_date, # TTL Attribute
                        'Status': 'GracePeriod',
                        'EstimatedMonthlyWaste': str(est_cost),
                        'Tags': tags
                    }
                )
                print(f"⚠️ Registered {vol_id} for cleanup. Deadline: {deletion_date}")
            else:
                print(f"ℹ️ {vol_id} is already in the queue.")

        except Exception as e:
            print(f"❌ Error processing {vol_id}: {str(e)}")

    return {"status": "Scan Complete", "scanned_count": len(unused_volumes)}
