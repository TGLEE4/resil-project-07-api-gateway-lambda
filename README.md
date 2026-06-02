# Project 7: API Gateway + Lambda

## Overview

This project exposes an existing AWS Lambda function through a public API Gateway HTTP endpoint.

The Lambda function was created in Project 6, and this project adds API Gateway as the public entry point.

## Architecture

```text
Internet User
    |
    v
API Gateway HTTP API
    |
    v
AWS Lambda Function
    |
    v
JSON Response