# Take advantage of AWS Network Manager Events to manage and monitor your global network - AWS CloudFormation

This repository shows an example of an automation solution that can be built taking advantage of [AWS Network Manager](https://docs.aws.amazon.com/network-manager/latest/tgwnm/what-are-global-networks.html) events. In this folder we provide code for this solution both using [AWS CloudFormation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html).

![Architecture](../images/nm-architecture.png)

## Usage & Deployment

* Clone the repository.

```
git clone https://github.com/aws-samples/monitor-automate-global-network-with-aws-network-manager.git
```

* In the *Makefile*, update the *INFRASTRUCTURE_REGION* and *EMAIL_ADDRESS* parameters with the AWS Region you want to build the Transit gateway network, and the email address to receive notifications from the SNS topic.
* **make deploy** will build first the automation solution and then the Transit gateway network.
* **make undeploy** will destroy all the resources created.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

