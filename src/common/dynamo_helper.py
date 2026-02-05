import boto3
import time
import os
from botocore.exceptions import ClientError

class DynamoHelper:
    def __init__(self, table_name, region):
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = self.dynamodb.Table(table_name)
        # Default Grace Period: 7 Days (in seconds)
        self.grace_period_seconds = 7 * 24 * 60 * 60 

    def register_resource(self, resource_id, resource_type, cost, tags):
        """
        Saves a resource to DynamoDB with a 7-day deletion timer.
        If the resource already exists, it updates the cost but DOES NOT reset the timer.
        """
        current_time = int(time.time())
        delete_at = current_time + self.grace_period_seconds

        try:
            # Try to insert ONLY if it doesn't exist yet
            self.table.put_item(
                Item={
                    'ResourceId': resource_id,
                    'ResourceType': resource_type,
                    'Status': 'GracePeriod',
                    'CreatedAt': current_time,
                    'DeleteAt': delete_at,
                    'EstimatedMonthlyWaste': str(cost), # Store as string to avoid Decimal issues
                    'Tags': tags
                },
                ConditionExpression='attribute_not_exists(ResourceId)'
            )
            print(f"⚠️ Registered new waste: {resource_id} (Type: {resource_type})")

        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                # Item exists! We just update the cost/tags, NOT the timer.
                print(f"🔄 {resource_id} is already tracking. Updating details...")
                self.table.update_item(
                    Key={'ResourceId': resource_id},
                    UpdateExpression="set EstimatedMonthlyWaste = :c, Tags = :t",
                    ExpressionAttributeValues={
                        ':c': str(cost),
                        ':t': tags
                    }
                )
            else:
                print(f"❌ Database Error: {e}")
