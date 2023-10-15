import json
import boto3
import os

def lambda_handler(event, context):
    try:
        # Obtaining information from the event
        timestamp = event['time']
        change_type = event['detail']['changeType']
        vpn_id = event['detail']['vpnConnectionArn']
        region = event['detail']['region']
        
        # Boto3 client
        dynamodb = boto3.client('dynamodb')
        # DynamoDB table
        table = os.environ['TABLE_NAME']
        # We log the event in the DynamoDB table
        dynamodb.put_item(
            TableName=table,
            Item={
                'vpn-id': {"S": vpn_id},
                'changeType': {"S": change_type},
                'awsRegion': {"S": region},
                'timestamp': {"S": timestamp}
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('Event logged!')
        }
    
    except Exception as e:
        # Printing the error in logs
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps('Something went wrong. Please check the logs.')
        }