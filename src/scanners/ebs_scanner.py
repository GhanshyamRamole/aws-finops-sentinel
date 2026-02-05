import boto3
import os
import logging
from datetime import datetime, timezone

# Initialize logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    dynamodb = boto3.resource('dynamodb')
    table_name = os.environ.get('DYNAMODB_TABLE') 
    
    if not table_name:
        logger.error("DYNAMODB_TABLE environment variable is missing")
        return
    
    table = dynamodb.Table(table_name)
    
    try:
        
        volumes = ec2.describe_volumes(Filters=[{'Name': 'status', 'Values': ['available']}])
        
        for vol in volumes['Volumes']:
            volume_id = vol['VolumeId']
            logger.info(f"Found orphaned volume: {volume_id}")
            
            # Record in DynamoDB for state tracking
            table.put_item(Item={
                'ResourceId': volume_id,
                'ResourceType': 'EBS',
                'DetectedAt': datetime.now(timezone.utc).isoformat(),
                'Status': 'Unused'
            })
            
    except Exception as e:
        logger.error(f"Error scanning EBS volumes: {str(e)}") 
