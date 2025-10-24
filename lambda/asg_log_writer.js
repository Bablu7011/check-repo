const AWS = require("aws-sdk");
const cloudwatchlogs = new AWS.CloudWatchLogs();

exports.handler = async (event) => {
  const logGroupName = process.env.LOG_GROUP;
  const logStreamName = new Date().toISOString().split("T")[0]; // daily log stream
  const message = JSON.stringify(event, null, 2);

  try {
    // Ensure log group exists
    await cloudwatchlogs.createLogGroup({ logGroupName }).promise().catch(() => {});
    await cloudwatchlogs.createLogStream({ logGroupName, logStreamName }).promise().catch(() => {});

    await cloudwatchlogs.putLogEvents({
      logGroupName,
      logStreamName,
      logEvents: [
        { message, timestamp: Date.now() }
      ]
    }).promise();

    console.log("✅ ASG event logged successfully");
  } catch (err) {
    console.error("❌ Error writing to CloudWatch Logs:", err);
  }

  return { statusCode: 200 };
};
