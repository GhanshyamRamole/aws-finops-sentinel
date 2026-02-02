import boto3
import os
from src.common.dynamo_helper import DynamoHelper

DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
REGION = os.environ['AWS_REGION']
elbv2 = boto3.client('elbv2', region_name=REGION)
db = DynamoHelper(DYNAMODB_TABLE, REGION)

def lambda_handler(event, context):
    print("🚀 Scanning for Orphaned Load Balancers...")
    
    # Scan Application/Network Load Balancers (v2)
    lbs = elbv2.describe_load_balancers()['LoadBalancers']
    
    for lb in lbs:
        lb_arn = lb['LoadBalancerArn']
        lb_name = lb['LoadBalancerName']
        
        # Check Target Groups attached to this LB
        tgs = elbv2.describe_target_groups(LoadBalancerArn=lb_arn)['TargetGroups']
        
        is_empty = True
        
        if not tgs:
            # No Target Groups at all -> Orphaned
            is_empty = True
        else:
            # Check if Target Groups have any healthy targets
            for tg in tgs:
                health = elbv2.describe_target_health(TargetGroupArn=tg['TargetGroupArn'])
                # If we find ANY target, we assume it's valid (simplify logic)
                if len(health['TargetHealthDescriptions']) > 0:
                    is_empty = False
                    break
        
        if is_empty:
            print(f"⚖️ Found empty LB: {lb_name}")
            # Cost: ALB is min ~$16/month + LCU hours
            db.register_resource(
                resource_id=lb_arn, # Using ARN as ID for uniqueness
                resource_type='Orphaned_LB',
                cost=16.00,
                tags={}
            )

    return {"status": "LB Scan Complete"}
