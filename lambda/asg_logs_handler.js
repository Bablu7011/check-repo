const AWS = require("aws-sdk");
const autoscaling = new AWS.AutoScaling({ region: "ap-south-1" });

exports.handler = async () => {
  try {
    const data = await autoscaling
      .describeScalingActivities({
        AutoScalingGroupName: "dev-asg", // 👈 replace with your ASG name
        MaxRecords: 10,
      })
      .promise();

    return {
      statusCode: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data.Activities),
    };
  } catch (err) {
    console.error("Error fetching ASG data:", err);
    return {
      statusCode: 500,
      headers: { "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify({ error: err.message }),
    };
  }
};
