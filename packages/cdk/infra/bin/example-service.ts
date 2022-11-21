#!/usr/bin/env node

/* eslint-disable no-new */
import * as cdk from 'aws-cdk-lib';
import { ExampleService } from '../example-service';
import { name, version } from '../../../../package.json';

const app = new cdk.App();

new ExampleService(app, 'cdkVsTfVsSlsVsCf-cdk-example', {
  tags: {
    serviceName: name,
    version,
  },
});
