# Amazon IVS Live to VOD (DVR) iOS demo

This iOS demo application is intended as an educational tool for demonstrating how you can implement a Live to VOD (DVR) experience using [Amazon IVS](https://aws.amazon.com/ivs/) and the auto-record-to-s3 feature using [Amazon S3](https://aws.amazon.com/s3/).

At a high level, it allows a viewer to seek back in time during a live stream and view recorded content from that stream. Viewers are also able to jump back to the live stream and resume watching content that is live.

<img src="app-screenshot.png" alt="An iPhone with the demo application running on the screen." />

## Setup

### 1. Using your own stream (optional)

In order to use your own stream with this demo you will need to deploy a backend solution on your AWS account. To do so, clone [amazon-ivs-dvr-web-demo](https://github.com/aws-samples/amazon-ivs-dvr-web-demo) and follow the deployment instructions available in the README.

Note that this solution will:

- Create an Amazon IVS channel
- Set up auto-record-to-S3 for that channel
- Create Lambda and Lambda@Edge resources to process VOD content
- Create a CloudFront distribution to serve the VOD content

Once deployment is done the CDK will output `distributionDomainName` that you'll need on the following step to run the demo

### 2. Run demo

- Clone this repository to your local machine.
- Ensure you are using a supported version of Ruby, as [the version included with macOS is deprecated](https://developer.apple.com/documentation/macos-release-notes/macos-catalina-10_15-release-notes#Scripting-Language-Runtimes). This repository is tested with the version in [`.ruby-version`](./.ruby-version.md), which can be used automatically with [rbenv](https://github.com/rbenv/rbenv#installation).
- Install the SDK dependency using CocoaPods. This can be done by running the following commands from the repository folder:
  - `pod install`
  - For more information about these commands, see [Bundler](https://bundler.io/) and [CocoaPods](https://guides.cocoapods.org/using/getting-started.html).
- Open Live-to-VOD.xcworkspace.
- To use the backend created in Step 1, open `Live to VOD UIKit/Constants.swift` and edit Line 9 with the `distributionDomainName` value from Step 1.
- You can now build and run the projects in the simulator.

## About Amazon IVS

Amazon Interactive Video Service (Amazon IVS) is a managed live streaming solution that is quick and easy to set up, and ideal for creating interactive video experiences. [Learn more](https://aws.amazon.com/ivs/).

- [Amazon IVS docs](https://docs.aws.amazon.com/ivs/)
- [User Guide](https://docs.aws.amazon.com/ivs/latest/userguide/)
- [API Reference](https://docs.aws.amazon.com/ivs/latest/APIReference/)
- [Setting Up for Streaming with Amazon Interactive Video Service](https://aws.amazon.com/blogs/media/setting-up-for-streaming-with-amazon-ivs/)
- [Learn more about Amazon IVS on IVS.rocks](https://ivs.rocks/)
- [View more demos like this](https://ivs.rocks/examples)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
