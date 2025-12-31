import json
import boto3
import csv

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('DailyDataLog')
    
    try:
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        print(f"Reading {key} from {bucket}")
        
        response = s3.get_object(Bucket=bucket, Key=key)
        data = response['Body'].read().decode('utf-8').splitlines()
        
        reader = csv.DictReader(data)
        count = 0
        for row in reader:
            print(f"Ingesting: {row}")
            table.put_item(Item=row)
            count += 1
            
        print(f"Successfully ingested {count} records")
        return {'statusCode': 200, 'body': f'Ingested {count} records'}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': str(e)}
