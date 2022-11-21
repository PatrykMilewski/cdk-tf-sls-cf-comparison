import { Construct } from 'constructs';
import { Stack, StackProps } from 'aws-cdk-lib';
import { NodejsFunction } from 'aws-cdk-lib/aws-lambda-nodejs';
import { AttributeType, BillingMode, StreamViewType, Table } from 'aws-cdk-lib/aws-dynamodb';
import { Bucket, EventType } from 'aws-cdk-lib/aws-s3';
import { S3EventSource } from 'aws-cdk-lib/aws-lambda-event-sources';
import { Stream } from 'aws-cdk-lib/aws-kinesis';

export class ExampleService extends Stack {
  constructor(scope: Construct, id: string, props: StackProps) {
    super(scope, id, props);

    const bucket = new Bucket(this, 'bucket', {});
    const lambda = new NodejsFunction(this, 'writer', {
      handler: './src/writer',
    });
    const stream = new Stream(this, 'stream', {
      shardCount: 1,
    });
    const table = new Table(this, 'table', {
      billingMode: BillingMode.PAY_PER_REQUEST,
      partitionKey: {
        name: 'pk',
        type: AttributeType.STRING,
      },
      stream: StreamViewType.NEW_AND_OLD_IMAGES,
      kinesisStream: stream,
    });
    table.grantWriteData(lambda);
    bucket.grantRead(lambda);
    const objectCreatedEventSource = new S3EventSource(bucket, {
      events: [EventType.OBJECT_CREATED_PUT],
      filters: [{ prefix: 'myPrefix/' }],
    });
    objectCreatedEventSource.bind(lambda);
  }
}
