const {
  CloudWatchLogsClient,
  CreateLogGroupCommand,
  CreateLogStreamCommand,
  DescribeLogStreamsCommand,
  PutLogEventsCommand,
} = require("@aws-sdk/client-cloudwatch-logs");

const cloudwatchlogs = new CloudWatchLogsClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
  const logGroupName = process.env.LOG_GROUP;
  const logStreamName = new Date().toISOString().split("T")[0]; // daily log stream
  const message = JSON.stringify(event, null, 2);

  try {
    // Create log group if missing
    try {
      await cloudwatchlogs.send(new CreateLogGroupCommand({ logGroupName }));
    } catch (e) {
      if (e.name !== "ResourceAlreadyExistsException") console.error(e);
    }

    // Create log stream if missing
    try {
      await cloudwatchlogs.send(new CreateLogStreamCommand({ logGroupName, logStreamName }));
    } catch (e) {
      if (e.name !== "ResourceAlreadyExistsException") console.error(e);
    }

    // Get sequence token if log stream already exists
    let uploadSequenceToken;
    try {
      const streams = await cloudwatchlogs.send(
        new DescribeLogStreamsCommand({ logGroupName, logStreamNamePrefix: logStreamName })
      );
      if (streams.logStreams && streams.logStreams.length > 0) {
        uploadSequenceToken = streams.logStreams[0].uploadSequenceToken;
      }
    } catch (e) {
      console.error("Error describing log streams:", e);
    }

    // Write log
    await cloudwatchlogs.send(
      new PutLogEventsCommand({
        logGroupName,
        logStreamName,
        logEvents: [{ message: `🪶 Auto Scaling Event:\n${message}`, timestamp: Date.now() }],
        sequenceToken: uploadSequenceToken,
      })
    );

    console.log("✅ ASG event logged successfully!");
  } catch (err) {
    console.error("❌ Error writing to CloudWatch Logs:", err);
  }

  return { statusCode: 200 };
};
