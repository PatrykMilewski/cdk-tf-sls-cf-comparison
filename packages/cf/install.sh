#!/bin/sh

which aws && exit 0

echo "AWS CLI must be installed in order to deploy CloudFormation stack"
exit 1
