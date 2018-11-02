#!/bin/bash
[ -z "${AWS_REGION}" ] && AWS_REGION="us-east-1"

/usr/local/bin/aws-env exec ./start.sh
