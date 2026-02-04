import boto3
import os
import datetime
from common.dynamo_helper import DynamoHelper

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
cloudwatch = boto3.client('cloudwatch', region_name=REGION)
ec2 = boto3.client('ec2', region_name=REGION)
db = DynamoHelper(DYNAMODB_TABLE, REGION)

def lambda_handler(event, context):
    print("🚀 Scanning for Idle EC2 Instances...")
    
    instances = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
    
    for reservation in instances['Reservations']:
        for inst in reservation['Instances']:
            inst_id = inst['InstanceId']
            
            # Check CPU utilization for last 14 days
            stats = cloudwatch.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName='CPUUtilization',
                Dimensions=[{'Name': 'InstanceId', 'Value': inst_id}],
                StartTime=datetime.datetime.utcnow() - datetime.timedelta(days=14),
                EndTime=datetime.datetime.utcnow(),
                Period=86400,
                Statistics=['Maximum']
            )
            
            # Logic: If Max CPU never exceeded 5% in 14 days, it's idle
            max_cpu = max([dp['Maximum'] for dp in stats['Datapoints']]) if stats['Datapoints'] else 0
            
            if max_cpu < 5.0:
                print(f"💤 {inst_id} is idle (Max CPU: {max_cpu}%)")
                # Estimate cost based on instance type (simplified)
                db.register_resource(inst_id, 'EC2_Idle', cost=20.00, tags={})
                
    return {"status": "EC2 Scan Complete"}
