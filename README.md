# Amazon IVS Live to Vod (DVR) Proof of Concept

Live to VOD (DVR) proof-of-concept using Amazon IVS and the auto-record-to-s3 feature.

At a high level, POC allows a viewer to seek back in time during a live stream and view recorded content from that stream. Viewers also are able to jump back to the live stream and start watching content that is live.

## Setup

1. Clone the repository to your local machine.
2. Ensure you are using a supported version of Ruby, as [the version included with macOS is deprecated](https://developer.apple.com/documentation/macos-release-notes/macos-catalina-10_15-release-notes#Scripting-Language-Runtimes). This repository is tested with the version in [`.ruby-version`](./.ruby-version.md), which can be used automatically with [rbenv](https://github.com/rbenv/rbenv#installation).
3. Install the SDK dependency using CocoaPods. This can be done by running the following commands from the repository folder:
   * `bundle install`
   * `bundle exec pod install --repo-update`
   * For more information about these commands, see [Bundler](https://bundler.io/) and [CocoaPods](https://guides.cocoapods.org/using/getting-started.html).
3. Open Live-to-VOD.xcworkspace.
4. Set `distributionDomainName` constant (can be found in `Constants.swift` file)
5. You can now build and run the projects in the simulator.

## License
This project is licensed under the MIT-0 License. See the LICENSE file.
