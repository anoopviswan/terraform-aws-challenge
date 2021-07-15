import boto3
import os
import sys
import uuid
from urllib.parse import unquote_plus
from PIL import Image
import PIL.Image

DEST_BUCKET = os.environ.get('DEST_BUCKET')
s3_client = boto3.client('s3')

def strip_image(image_path, resized_path):
    with Image.open(image_path) as image:
        image.save(resized_path)

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        tmpkey = key.replace('/', '')
        download_path = '/tmp/{}{}'.format(uuid.uuid4(), tmpkey)
        upload_path = '/tmp/stripped/{}'.format(tmpkey)
        s3_client.download_file(bucket, key, download_path)
        strip_image(download_path, upload_path)
        s3_client.upload_file(upload_path, '{}'.format(DEST_BUCKET), key)