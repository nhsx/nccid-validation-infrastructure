# AWS ElasticSearch with Cognito

**WARNING:** This requires manual steps after running Terraform:

Background: https://github.com/hashicorp/terraform-provider-aws/issues/5557#issuecomment-491477178

AWS ES with Cognito automatically creates a Cognito client which means Terraform can't create everything correctly (though sometimes it does in which case just check that `Authentication providers` is correct).

After running Terraform the first time you _may_ need to fix some settings:
1. Log into AWS
2. Go to the Cognito service
3. Under `User Pools` open the user pool
4. Make a note of the `Pool Id`
5. Click `App integration / App client settings`
6. Make a note of the `ID` of the app called `App client AWSElasticsearch-...`
7. Go to `Federated Identities`, open the identity pool and click `Edit identity pool`
8. Scroll down to `Authentication providers` and expand it
9. On the `Cognito` tab set `User Pool ID` to the ID from step 4 _if it's not set_.
10. Set the `App client id` to the ID from step 6 _if it's not set_.
11. Scroll to the bottom and click `Save Changes`

This also creates an ES admin role that can be used with e.g. https://docs.amazonaws.cn/en_us/AmazonCloudWatch/latest/logs/CWL_ES_Stream.html
