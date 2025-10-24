// ============================
// ASG Activity Dashboard Script
// ============================

// 🔹 Replace this with your Terraform output API Gateway endpoint
const API_URL = "https://x5xt1dv5da.execute-api.ap-south-1.amazonaws.com/scaling-logs";
const region = "ap-south-1";

const statusEl = document.getElementById("status");
const tableEl = document.getElementById("data-table");
const tbodyEl = document.getElementById("table-body");
const asgNameEl = document.getElementById("asg-name");
const regionEl = document.getElementById("aws-region");
const refreshBtn = document.getElementById("refresh-btn");

refreshBtn.addEventListener("click", refreshData);

async function refreshData() {
  statusEl.textContent = "Fetching latest scaling activities...";
  tableEl.classList.remove("show");
  tbodyEl.innerHTML = "";

  try {
    const response = await fetch(API_URL);
    if (!response.ok) throw new Error(`HTTP error ${response.status}`);

    const data = await response.json();

    // Expecting data like: { asgName: "dev-asg", activities: [...] }
    const { asgName, activities } = data;
    if (data.summary) {
      document.getElementById("summary").innerHTML = `
        📈 Scale-Outs Today: <span class="highlight">${data.summary.scaleOutCount}</span> |
        📉 Scale-Ins Today: <span class="highlight">${data.summary.scaleInCount}</span>
      `;
    }


    asgNameEl.textContent = asgName || "N/A";
    regionEl.textContent = region;

    if (!activities || activities.length === 0) {
      tbodyEl.innerHTML = `
        <tr><td colspan="4" style="text-align:center; color:#9ca3af;">No recent scaling activities found.</td></tr>
      `;
      tableEl.classList.add("show");
      statusEl.textContent = "Last updated: " + new Date().toLocaleTimeString();
      return;
    }

    // Populate the table
    activities.forEach(item => {
      const row = document.createElement("tr");
      row.innerHTML = `
        <td>${item.time || "-"}</td>
        <td>${item.description || "-"}</td>
        <td>${item.cause || "-"}</td>
        <td class="status ${getStatusClass(item.status)}">${item.status}</td>
      `;
      tbodyEl.appendChild(row);
    });

    // Show updated data
    statusEl.textContent = "Last updated: " + new Date().toLocaleTimeString();
    tableEl.classList.add("show");
  } catch (err) {
    console.error("Error fetching data:", err);
    statusEl.textContent = "❌ Failed to load data. Try again.";
  }
}

function getStatusClass(status = "") {
  const s = status.toLowerCase();
  if (s.includes("success")) return "status-success";
  if (s.includes("fail")) return "status-failed";
  if (s.includes("progress")) return "status-inprogress";
  return "";
}

// Auto-refresh when page loads
window.onload = refreshData;
