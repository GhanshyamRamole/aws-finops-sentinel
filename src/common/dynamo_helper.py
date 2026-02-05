import boto3
import logging

logger = logging.getLogger()

class DynamoHelper:
    def __init__(self, table_name):
        self.table = boto3.resource('dynamodb').Table(table_name)

    def mark_resource_for_deletion(self, resource_id, resource_type):
        try:
            self.table.put_item(Item={
                'ResourceId': resource_id,
                'ResourceType': resource_type,
                'Action': 'Pending-Deletion'
            })
        except Exception as e:
            logger.error(f"DynamoDB Error: {str(e)}")
