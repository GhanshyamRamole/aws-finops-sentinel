import boto3
import time
from datetime import datetime, timedelta

class DynamoHelper:
    def __init__(self, table_name, region):
        self.dynamodb = boto3.resource('dynamodb', region_name=region)
        self.table = self.dynamodb.Table(table_name)

    def register_resource(self, resource_id, resource_type, cost, tags, grace_days=7):
        """Adds a resource to the table if it doesn't already exist."""
        try:
            # Check if exists
            if 'Item' in self.table.get_item(Key={'ResourceId': resource_id}):
                print(f"ℹ️ {resource_id} is already tracked.")
                return

            delete_at = int((datetime.now() + timedelta(days=grace_days)).timestamp())
            
            self.table.put_item(
                Item={
                    'ResourceId': resource_id,
                    'ResourceType': resource_type,
                    'DetectedAt': int(time.time()),
                    'DeleteAt': delete_at,
                    'Status': 'GracePeriod',
                    'EstimatedMonthlyWaste': str(cost),
                    'Tags': tags
                }
            )
            print(f"⚠️ Registered {resource_id} (Type: {resource_type})")
        except Exception as e:
            print(f"❌ DB Error: {e}")
