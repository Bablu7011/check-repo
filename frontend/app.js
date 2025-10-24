// 🔗 Replace this URL after terraform apply
const API_URL = "https://REPLACE_WITH_YOUR_API_GATEWAY_URL/scaling-logs";

async function refreshData() {
  const status = document.getElementById("status");
  const btn = document.getElementById("refresh-btn");
  const table = document.getElementById("data-table");
  const tbody = document.getElementById("table-body");

  btn.disabled = true;
  status.textContent = "⏳ Loading scaling activities...";
  tbody.innerHTML = "";
  table.style.display = "none";

  try {
    const res = await fetch(API_URL);
    const data = await res.json();

    if (!Array.isArray(data) || data.length === 0) {
      status.textContent = "⚠️ No recent scaling activities found.";
    } else {
      table.style.display = "table";
      data.forEach((item) => {
        const row = document.createElement("tr");
        row.innerHTML = `
          <td>${new Date(item.StartTime).toLocaleString()}</td>
          <td>${item.Description}</td>
          <td>${item.Cause}</td>
          <td>${item.StatusCode}</td>
        `;
        tbody.appendChild(row);
      });
      status.textContent = "✅ Latest scaling activities loaded.";
    }
  } catch (err) {
    console.error(err);
    status.textContent = "❌ Failed to load data. Try again.";
  }

  btn.disabled = false;
}
