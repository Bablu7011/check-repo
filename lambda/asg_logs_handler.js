import { AutoScalingClient, DescribeScalingActivitiesCommand } from "@aws-sdk/client-auto-scaling";

export const handler = async () => {
  const client = new AutoScalingClient({ region: "ap-south-1" });
  const asgName = "dev-asg";
  const today = new Date().toISOString().split("T")[0];

  try {
    const data = await client.send(
      new DescribeScalingActivitiesCommand({
        AutoScalingGroupName: asgName,
        MaxRecords: 20,
      })
    );

    const activities = data.Activities.map((a) => ({
      time: new Date(a.StartTime).toISOString().replace("T", " ").slice(0, 19),
      description: a.Description || "N/A",
      cause: a.Cause || "N/A",
      status: a.StatusCode || "Unknown",
    }));

    let scaleOutCount = 0;
    let scaleInCount = 0;

    activities.forEach((a) => {
      const activityDate = a.time.split(" ")[0];
      if (activityDate === today) {
        if (a.description.toLowerCase().includes("launch")) scaleOutCount++;
        if (a.description.toLowerCase().includes("terminate")) scaleInCount++;
      }
    });

    const response = {
      asgName,
      summary: { date: today, scaleOutCount, scaleInCount },
      activities,
    };

    return {
      statusCode: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(response),
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
