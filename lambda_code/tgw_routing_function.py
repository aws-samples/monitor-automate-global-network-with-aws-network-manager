import json
import boto3
import os

def lambda_handler(event, context):
    try:
        # Obtaining information from the event
        region = event['region']
        tgw_attachment = event['transitGatewayAttachmentArn'].split('/')[1]
        # Obtaining SSM Parameter name from environment variables
        parameter = os.environ['PARAMETER_NAME']
        
        # Boto3 clients
        ssm = boto3.client('ssm', region_name=region)
        ec2 = boto3.client('ec2', region_name=region)

        # Obtaining the Transit Gateway route table ID from Systems Manager Parameter Store
        tgw_rt = ssm.get_parameter( Name=parameter)

        # We create Transit Gateway association and propagation to the route table
        tgw_association = ec2.associate_transit_gateway_route_table(
            TransitGatewayRouteTableId=tgw_rt,
            TransitGatewayAttachmentId=tgw_attachment
        )['Association']['ResourceId']
        tgw_propagation = ec2.enable_transit_gateway_route_table_propagation(
            TransitGatewayRouteTableId=tgw_rt,
            TransitGatewayAttachmentId=tgw_attachment
        )['Propagation']['ResourceId']
        
        return {
            'statusCode': 200,
            'body': {
                'transitGatewayAssociationId': tgw_association,
                'transitGatewayPropagationId': tgw_propagation
            }
        }
    
    except Exception as e:
        # Printing the error in logs
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps('Something went wrong. Please check the logs.')
        }