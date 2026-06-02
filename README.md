# Project 7 -- API Gateway + Lambda

## Overview

In this project, I exposed an existing AWS Lambda function through a public API Gateway HTTP endpoint.

The Lambda function, `resil-hello-lambda`, was created in Project 6. In Project 7, I added API Gateway in front of that Lambda function so users can call the function through a normal HTTPS URL instead of invoking it manually through the AWS CLI.

This project demonstrates a basic serverless API pattern:

```text
User sends HTTP request
↓
API Gateway receives request
↓
API Gateway forwards request to Lambda
↓
Lambda runs code
↓
Lambda returns response
↓
User receives response
```

In plain English, Project 6 created the worker. Project 7 built the public front door so people can reach that worker over the internet.

House analogy: the Lambda function is like a worker inside a building. Before this project, only the building owner could directly tell the worker what to do through AWS CLI. API Gateway acts like the public entrance and doorbell. When someone visits the API URL, API Gateway rings the bell and tells Lambda to run.

---

## Goals

* Expose the existing `resil-hello-lambda` function through a public HTTP endpoint
* Create an API Gateway HTTP API using Terraform
* Add a `/hello` route that maps to the Lambda function
* Use Lambda proxy integration so API Gateway can pass requests directly to Lambda
* Grant API Gateway permission to invoke the Lambda function
* Output the public API URL from Terraform
* Test the API using `curl`
* Save the test response locally as `response.json`
* Push the project code to a dedicated GitHub repo
* Update the live portfolio site with Project 7
* Update the main roadmap index repo to mark Project 7 complete
* Destroy only the Project 7 API Gateway resources after testing

---

## Tools & Environment

| Tool            | Version / Setup                        |
| --------------- | -------------------------------------- |
| OS              | Ubuntu 24.04.4 LTS through WSL2        |
| Terraform       | v1.15.3                                |
| AWS CLI         | 2.34.48                                |
| Git             | 2.43.0                                 |
| GitHub CLI      | 2.45.0                                 |
| Editor          | VS Code opened from WSL using `code .` |
| AWS Region      | `us-east-1`                            |
| AWS CLI Profile | `default`                              |
| Existing Lambda | `resil-hello-lambda`                   |

---

## Architecture

```text
Internet User
    |
    | GET /hello
    v
API Gateway HTTP API
    |
    | AWS_PROXY integration
    v
AWS Lambda Function
    |
    | JSON/Text response
    v
API Gateway returns response to user
```

More specifically:

```text
curl https://example-api-id.execute-api.us-east-1.amazonaws.com/hello
↓
API Gateway route: GET /hello
↓
Lambda integration
↓
resil-hello-lambda
↓
Lambda response returned to terminal/browser
```

This is one of the most common serverless cloud patterns: API Gateway + Lambda.

---

## Infrastructure Built

| Resource                                    | Purpose                                                       |
| ------------------------------------------- | ------------------------------------------------------------- |
| `data.aws_lambda_function.hello`            | Reads the existing `resil-hello-lambda` function from AWS     |
| `aws_apigatewayv2_api.hello_api`            | Creates the HTTP API Gateway resource                         |
| `aws_apigatewayv2_integration.hello_lambda` | Connects API Gateway to the Lambda function                   |
| `aws_apigatewayv2_route.hello_route`        | Creates the `GET /hello` route                                |
| `aws_apigatewayv2_stage.default`            | Creates the default deployment stage with auto-deploy enabled |
| `aws_lambda_permission.allow_api_gateway`   | Allows API Gateway to invoke the Lambda function              |
| `output.api_url`                            | Prints the public API URL after deployment                    |

Important detail: this project did not create the Lambda function. It only connected to an existing one.

That matters because the Lambda function belongs to Project 6. Project 7 owns only the API Gateway layer and the permission allowing API Gateway to invoke the function.

---

## File Structure

```text
resil-project-07-api-gateway-lambda/
├── .gitignore              # Excludes Terraform local files, state, tfvars, zip files, and response.json
├── provider.tf             # AWS provider configuration
├── main.tf                 # API Gateway, Lambda integration, route, stage, permission
├── outputs.tf              # Public API URL output
├── README.md               # Project documentation
└── .terraform.lock.hcl     # Terraform provider dependency lock file
```

Local files intentionally ignored by Git:

```text
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars
*.pem
lambda.zip
response.json
```

The `.terraform.lock.hcl` file was intentionally committed because it locks the Terraform provider version and helps make future runs consistent.

---

## Step by Step -- What I Did and Why

### Step 1 -- Created the Project 7 folder

Created a new folder:

```bash
~/resil-roadmap/resil-project-07-api-gateway-lambda
```

This keeps Project 7 separate from the earlier projects.

Why this matters: each cloud project has its own GitHub repo, its own Terraform files, and its own README. This makes the portfolio easier for employers to inspect. Instead of one messy repo with everything mixed together, each project demonstrates one specific cloud skill.

---

### Step 2 -- Created `.gitignore` before Terraform init

Created `.gitignore` before running `terraform init`.

The file included:

```gitignore
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars
*.pem
lambda.zip
response.json
```

Why this matters: Terraform creates local files that should not be uploaded to GitHub. The most important one is `terraform.tfstate`, which can contain real AWS resource details.

This follows the lesson learned from earlier projects: always create `.gitignore` before running `terraform init`.

House analogy: before inviting people to inspect the house, I put private paperwork in a locked drawer. GitHub should show the blueprint, not private operational records.

---

### Step 3 -- Initialized Git

Ran:

```bash
git init
```

This turned the folder into a Git repository.

Why this matters: Git tracks each project checkpoint. Every cloud engineering project should have version control so changes are reviewable, reversible, and easy to share.

---

### Step 4 -- Created `provider.tf`

Created the Terraform provider configuration:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}
```

What this does:

* Tells Terraform to use the official AWS provider
* Uses provider version `~> 6.0`
* Deploys into `us-east-1`
* Uses the AWS CLI profile named `default`

Why `us-east-1` matters: the existing Lambda function `resil-hello-lambda` is in `us-east-1`, so the API Gateway configuration also needs to operate in that region.

Why `profile = "default"` matters: the AWS CLI on this machine is configured with the `default` profile, not a separate `resil-admin` profile.

---

### Step 5 -- Checked Terraform formatting and validation

Ran:

```bash
terraform fmt
terraform init
terraform validate
```

What each command does:

```bash
terraform fmt
```

Formats Terraform files so spacing and indentation are clean.

```bash
terraform init
```

Downloads the AWS provider and prepares the project for Terraform operations.

```bash
terraform validate
```

Checks whether the Terraform configuration is structurally valid.

Why this matters: in real cloud engineering work, you do not jump straight to deploying. You first check formatting, initialize dependencies, and validate the code.

This catches mistakes before Terraform touches AWS.

---

### Step 6 -- Created `main.tf`

The `main.tf` file defined the core Project 7 infrastructure.

#### Section 1 -- Read the existing Lambda function

```hcl
data "aws_lambda_function" "hello" {
  function_name = "resil-hello-lambda"
}
```

This is a Terraform data source.

A data source means Terraform is reading an existing AWS resource instead of creating a new one.

Why this matters: Project 6 already created the Lambda function. Project 7 should not recreate it, replace it, or destroy it. It only needs to look it up and connect API Gateway to it.

House analogy: this is like looking up the worker's office location before installing a doorbell. You are not hiring a new worker; you are connecting visitors to the existing one.

---

#### Section 2 -- Create the HTTP API

```hcl
resource "aws_apigatewayv2_api" "hello_api" {
  name          = "resil-project-07-api"
  protocol_type = "HTTP"
}
```

This creates an API Gateway version 2 HTTP API.

Why HTTP API was used: API Gateway has different API types. HTTP APIs are simpler and cheaper than REST APIs for basic Lambda-backed endpoints.

This project only needed a simple route:

```text
GET /hello
```

So HTTP API was the right choice.

---

#### Section 3 -- Create the Lambda integration

```hcl
resource "aws_apigatewayv2_integration" "hello_lambda" {
  api_id                 = aws_apigatewayv2_api.hello_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = data.aws_lambda_function.hello.invoke_arn
  payload_format_version = "2.0"
}
```

This connects API Gateway to Lambda.

Important parts:

```hcl
api_id = aws_apigatewayv2_api.hello_api.id
```

Connects the integration to the API Gateway HTTP API.

```hcl
integration_type = "AWS_PROXY"
```

Uses Lambda proxy integration.

This means API Gateway forwards the request to Lambda in a standard event format, and Lambda returns the response back through API Gateway.

```hcl
integration_uri = data.aws_lambda_function.hello.invoke_arn
```

Uses the Lambda invoke ARN from the existing Lambda function.

```hcl
payload_format_version = "2.0"
```

Uses the HTTP API payload format version 2.0, which is the common format for API Gateway HTTP APIs.

Why this matters: the integration is the bridge between the public API URL and the Lambda function. Without it, API Gateway would exist, but it would not know what backend service to call.

---

#### Section 4 -- Create the `/hello` route

```hcl
resource "aws_apigatewayv2_route" "hello_route" {
  api_id    = aws_apigatewayv2_api.hello_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_lambda.id}"
}
```

This creates the public API route.

The route key:

```hcl
route_key = "GET /hello"
```

means:

```text
When someone sends an HTTP GET request to /hello, trigger the Lambda integration.
```

Why this matters: API Gateway can have multiple routes. For this project, there is one route:

```text
GET /hello
```

House analogy: the API is the building. The route is a specific door. In this case, the door says `/hello`.

---

#### Section 5 -- Create the default stage

```hcl
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.hello_api.id
  name        = "$default"
  auto_deploy = true
}
```

A stage is a deployed version of the API.

Using:

```hcl
name = "$default"
```

means the API can be reached without needing an extra stage name in the URL.

For example, the URL becomes:

```text
https://api-id.execute-api.us-east-1.amazonaws.com/hello
```

instead of:

```text
https://api-id.execute-api.us-east-1.amazonaws.com/prod/hello
```

Using:

```hcl
auto_deploy = true
```

means route and integration changes are automatically deployed.

Why this matters: without a stage, the API may exist but not be reachable. The stage is what makes the route live.

---

#### Section 6 -- Grant API Gateway permission to call Lambda

```hcl
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromProject07APIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.hello.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.hello_api.execution_arn}/*/*"
}
```

This gives API Gateway permission to invoke the Lambda function.

This is required because Lambda is protected by IAM permissions. Even though API Gateway exists, AWS will not automatically allow it to run the Lambda function unless permission is explicitly granted.

Important parts:

```hcl
action = "lambda:InvokeFunction"
```

Allows invocation of the Lambda function.

```hcl
principal = "apigateway.amazonaws.com"
```

Says the service receiving permission is API Gateway.

```hcl
function_name = data.aws_lambda_function.hello.function_name
```

Applies permission to the existing `resil-hello-lambda`.

```hcl
source_arn = "${aws_apigatewayv2_api.hello_api.execution_arn}/*/*"
```

Restricts the permission to this API Gateway execution ARN.

Why this matters: this is the security connection. API Gateway needs permission to ring the Lambda doorbell.

---

### Step 7 -- Created `outputs.tf`

Created:

```hcl
output "api_url" {
  description = "Public API Gateway URL for the hello route"
  value       = "${aws_apigatewayv2_api.hello_api.api_endpoint}/hello"
}
```

This prints the final test URL after deployment.

Why this matters: after Terraform creates the API Gateway, I need a clean way to retrieve the endpoint without digging through the AWS Console.

The output produced a URL like:

```text
https://example-id.execute-api.us-east-1.amazonaws.com/hello
```

That URL is the public entry point for the Lambda-backed API.

---

### Step 8 -- Ran `terraform plan`

Ran:

```bash
terraform plan
```

The expected result was:

```text
5 to add, 0 to change, 0 to destroy
```

The planned resources were:

```text
aws_apigatewayv2_api
aws_apigatewayv2_integration
aws_apigatewayv2_route
aws_apigatewayv2_stage
aws_lambda_permission
```

Why this mattered: `terraform plan` confirmed Terraform was only creating the Project 7 API Gateway resources and permission. It was not trying to create, modify, or destroy the existing Lambda function.

This is a major safety step in Terraform work.

---

### Step 9 -- Ran `terraform apply`

Ran:

```bash
terraform apply
```

Then confirmed with:

```text
yes
```

Terraform created the API Gateway resources and printed the output:

```text
api_url = "https://example-id.execute-api.us-east-1.amazonaws.com/hello"
```

Why this matters: this was the actual deployment step. After this, the Lambda function could be reached through a public HTTPS endpoint.

---

### Step 10 -- Tested the public API

First retrieved the API URL:

```bash
terraform output api_url
```

Then called the endpoint:

```bash
curl "$(terraform output -raw api_url)"
```

The API Gateway endpoint successfully triggered the Lambda function and returned a response.

Why this matters: deployment is not complete until the system is tested from the outside. Terraform can successfully create resources, but the only way to know the architecture works end-to-end is to make an actual request.

The real test path was:

```text
curl
↓
API Gateway public URL
↓
GET /hello route
↓
Lambda proxy integration
↓
resil-hello-lambda
↓
response returned to terminal
```

---

### Step 11 -- Saved the test response

Ran:

```bash
curl "$(terraform output -raw api_url)" > response.json
cat response.json
```

This saved the API response locally.

Why this matters: `response.json` is proof that the endpoint worked during testing.

It was intentionally ignored by Git using `.gitignore`, because test output files should not be committed to the repo.

---

### Step 12 -- Wrote `README.md`

Created project documentation explaining:

* what the project does
* which AWS services were used
* what Terraform resources were created
* how the architecture works
* how to test the endpoint
* what skills were practiced

Why this matters: the README turns a technical lab into a portfolio project. Employers should be able to open the repo and quickly understand the purpose, design, and outcome.

---

### Step 13 -- Checked Git status

Ran:

```bash
git status
```

Confirmed Git saw the correct files:

```text
.gitignore
.terraform.lock.hcl
README.md
main.tf
outputs.tf
provider.tf
```

Confirmed Git did not include:

```text
.terraform/
terraform.tfstate
terraform.tfstate.backup
response.json
```

Why this matters: this was the final safety check before committing. It confirmed that sensitive or local-only files were not going to GitHub.

---

### Step 14 -- Committed the project

Ran:

```bash
git add .
git commit -m "Add API Gateway Lambda project"
```

This saved the Project 7 code into local Git history.

Important concept: `git add .` stages files. Staging means selecting which files will be included in the next commit.

The flow is:

```text
Working folder
↓
Staging area
↓
Commit history
```

House analogy: staging is putting the documents on the table. Committing is taking the official snapshot.

---

### Step 15 -- Created the GitHub repo and pushed

Ran:

```bash
gh repo create resil-project-07-api-gateway-lambda --public --source=. --remote=origin
git branch -M main
git push --set-upstream origin main
```

This created the public GitHub repo:

```text
https://github.com/TGLEE4/resil-project-07-api-gateway-lambda
```

Why this matters: the project became publicly visible and usable as part of the cloud portfolio.

---

### Step 16 -- Updated the live portfolio

Updated the local portfolio source file:

```text
~/resil-roadmap/tenglee-portfolio/index.html
```

Changes made:

* changed the hero stat from `6+` to `7+`
* added a new Project 7 card
* linked the card to the Project 7 GitHub repo

Then uploaded the updated file to S3:

```bash
aws s3 cp ~/resil-roadmap/tenglee-portfolio/index.html s3://tenglee.dev/
```

Then invalidated CloudFront cache:

```bash
aws cloudfront create-invalidation --distribution-id $(aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[?contains(@, 'tenglee.dev')]].Id" --output text) --paths "/*"
```

Why this matters: the S3 upload updated the origin file, and the CloudFront invalidation forced the CDN to fetch the newest version instead of serving a cached copy.

---

### Step 17 -- Updated the roadmap index repo

Updated:

```text
~/resil-roadmap/Cloud-Computing-Project-Roadmap/README.md
```

Changed Project 7 from:

```markdown
| 7 | API Gateway + Lambda | coming soon | 🔲 Upcoming |
```

to:

```markdown
| 7 | API Gateway + Lambda | [resil-project-07-api-gateway-lambda](https://github.com/TGLEE4/resil-project-07-api-gateway-lambda) | ✅ Complete |
```

Then committed and pushed:

```bash
git add README.md
git commit -m "Mark Project 7 complete"
git push
```

Why this matters: the index repo now reflects the current roadmap status.

---

### Step 18 -- Committed and pushed the portfolio source update

Inside:

```text
~/resil-roadmap/tenglee-portfolio
```

Ran:

```bash
git add index.html
git commit -m "Add Project 7 to portfolio"
git push
```

Why this matters: the live website and the GitHub source now match.

Without this step, `tenglee.dev` would show the new Project 7 card, but the portfolio source repo would still be outdated.

---

### Step 19 -- Destroyed Project 7 AWS resources

Ran:

```bash
terraform destroy
```

Then confirmed:

```text
yes
```

Terraform destroyed the resources created by Project 7:

```text
aws_apigatewayv2_api
aws_apigatewayv2_integration
aws_apigatewayv2_route
aws_apigatewayv2_stage
aws_lambda_permission
```

Why this matters: this avoided leaving unnecessary API Gateway resources active after the project was complete.

Important: the existing Lambda function `resil-hello-lambda` was not destroyed. Project 7 only referenced it as a Terraform data source.

---

## Tradeoff 1 -- HTTP API vs REST API

### What this means

API Gateway has two common API types:

* HTTP API
* REST API

Both can expose Lambda functions through public endpoints.

### What I chose

I used API Gateway HTTP API.

### Why

HTTP APIs are simpler, faster to configure, and usually cheaper than REST APIs. This project only needed a basic public endpoint:

```text
GET /hello
```

There was no need for advanced REST API features like usage plans, API keys, request validation, or complex gateway transformations.

### The tradeoff

HTTP APIs are great for lightweight serverless APIs, but REST APIs have more mature advanced features.

For this project, HTTP API was the better fit because the goal was to expose Lambda through a clean public URL with minimal complexity.

Cloud engineering takeaway: choose the simplest service that satisfies the requirement. Do not overbuild.

---

## Tradeoff 2 -- Existing Lambda Data Source vs Creating a New Lambda

### What this means

Terraform could either:

* Create a new Lambda function inside Project 7
* Read the existing Lambda function from Project 6

### What I chose

I used a data source:

```hcl
data "aws_lambda_function" "hello" {
  function_name = "resil-hello-lambda"
}
```

### Why

The Lambda function already existed from Project 6. Project 7's purpose was not to rebuild Lambda. The purpose was to expose that Lambda through API Gateway.

This kept the project focused.

### The tradeoff

Using an existing Lambda makes Project 7 depend on Project 6. If `resil-hello-lambda` does not exist, Project 7 cannot deploy.

Creating a new Lambda inside Project 7 would make the project more self-contained, but it would duplicate work already completed in Project 6.

Cloud engineering takeaway: sometimes infrastructure projects depend on existing resources. Terraform data sources are how you safely reference those resources without taking ownership of them.

---

## Tradeoff 3 -- `$default` Stage vs Named Stage

### What this means

API Gateway stages control how an API is deployed.

A named stage might produce a URL like:

```text
https://api-id.execute-api.us-east-1.amazonaws.com/prod/hello
```

A `$default` stage produces a cleaner URL:

```text
https://api-id.execute-api.us-east-1.amazonaws.com/hello
```

### What I chose

I used:

```hcl
name = "$default"
```

with:

```hcl
auto_deploy = true
```

### Why

For a beginner serverless API project, the `$default` stage keeps the URL simple and avoids extra stage path complexity.

### The tradeoff

Named stages like `dev`, `test`, and `prod` are better for larger real-world systems where different environments need to be separated.

For this project, `$default` was enough.

Cloud engineering takeaway: `$default` is useful for simple APIs, but production teams often use separate stages or separate AWS accounts for environment isolation.

---

## Tradeoff 4 -- Public Endpoint vs Private/Internal API

### What this means

An API Gateway endpoint can be public or private.

A public endpoint is reachable from the internet.

A private API is only reachable inside a VPC or through controlled internal networking.

### What I chose

I created a public endpoint.

### Why

The purpose of the project was to expose Lambda through a public HTTP URL and test it using `curl`.

### The tradeoff

A public endpoint is easier to test and demonstrate, but it needs proper security if used for real workloads.

This project did not add authentication, API keys, rate limits, WAF, or custom domain protection. For a production API, those would be important next steps.

Cloud engineering takeaway: public APIs need security controls. This project focused on the core API Gateway-to-Lambda connection first.

---

## Lessons Learned

* API Gateway acts as the public front door for Lambda.
* Lambda by itself does not automatically have a public HTTP URL.
* API Gateway needs an integration to know which backend service to call.
* A route like `GET /hello` tells API Gateway which requests should trigger the integration.
* Lambda proxy integration lets API Gateway pass the request to Lambda using a standard event format.
* API Gateway needs explicit permission to invoke Lambda.
* `aws_lambda_permission` is required even when API Gateway and Lambda are in the same AWS account.
* Terraform data sources read existing infrastructure without managing or destroying it.
* `terraform plan` is a critical safety check before applying changes.
* `terraform output -raw` is useful for scripting because it removes quotes from output values.
* `response.json` is useful for local testing but should not be committed.
* CloudFront cache must be invalidated after uploading a changed portfolio file to S3.
* The live portfolio, portfolio source repo, project repo, and roadmap index should all stay in sync.

---

## How to Deploy

```bash
# Go to roadmap workspace
cd ~/resil-roadmap

# Enter Project 7 folder
cd resil-project-07-api-gateway-lambda

# Initialize Terraform
terraform init

# Format Terraform files
terraform fmt

# Validate Terraform code
terraform validate

# Preview infrastructure changes
terraform plan

# Deploy infrastructure
terraform apply

# Confirm with yes when prompted
```

---

## How to Test

```bash
# Print the API URL
terraform output -raw api_url

# Call the API endpoint
curl "$(terraform output -raw api_url)"

# Save the response locally
curl "$(terraform output -raw api_url)" > response.json
cat response.json
```

Expected flow:

```text
curl command
↓
API Gateway URL
↓
GET /hello
↓
Lambda function
↓
response returned
```

---

## How to Destroy

```bash
terraform destroy
```

Then confirm:

```text
yes
```

This destroys the Project 7 API Gateway resources and Lambda permission.

It does not destroy:

```text
resil-hello-lambda
tenglee.dev
Route 53 hosted zone
CloudFront distribution for portfolio
S3 bucket for portfolio
ACM certificate for portfolio
```

Reason: those resources are not owned by this Project 7 Terraform configuration.

---

## What This Project Demonstrates to Employers

This project demonstrates that I can:

* Build a serverless API using AWS-managed services
* Connect API Gateway to Lambda
* Use Terraform to manage API infrastructure
* Reference existing AWS resources safely with data sources
* Grant least-required service permission with `aws_lambda_permission`
* Test cloud infrastructure from the command line
* Document the architecture clearly
* Maintain separate GitHub repos per project
* Update a live cloud-hosted portfolio
* Clean up AWS resources after testing

This is directly relevant to Cloud Infrastructure Engineer work because many modern systems are built with managed services, event-driven compute, infrastructure as code, and command-line validation.

---

## Final Project Summary

Project 7 took the Lambda function created in Project 6 and made it reachable through a public HTTPS API endpoint.

The final architecture was:

```text
Public HTTPS request
↓
API Gateway HTTP API
↓
GET /hello route
↓
AWS_PROXY Lambda integration
↓
resil-hello-lambda
↓
Response returned to user
```

This project added an important cloud engineering skill: exposing backend compute through a managed API layer.

Project 6 proved that I could create and run serverless compute.

Project 7 proved that I could turn that serverless function into a public API.
