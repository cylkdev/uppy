# Introduction

LocalStack is used to run aws applications entirely on the local machine without connecting to the web service! See the [localstack](https://github.com/localstack/localstack) documentation for more information.

Once your localstack instance is running create the s3 bucket `uppy-test`.

You can do this with `awslocal`

```bash
awslocal s3 mb s3://uppy-test
```

or `aws` cli if you have configured a profile and/or do not have `awslocal`:

```bash
# ~/.aws/config

[profile localstack]
endpoint_url = http://localhost:4566
region = us-west-1
output = json
```

```bash
# shell
> export AWS_PROFILE=localstack
> aws s3 mb s3://uppy-test
```