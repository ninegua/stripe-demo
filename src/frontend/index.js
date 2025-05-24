const backend = process.env.CANISTER_ID_STRIPE_BACKEND;
const backendURL =
  process.env.DFX_NETWORK == "local"
    ? `http://${backend}.raw.localhost:4943`
    : `https://${backend}.raw.icp0.io`;

function clearLogs() {
  document.getElementById("log").innerHTML = "";
}

function logLine(line, linebreak = true) {
  document.getElementById("log").innerHTML += line + (linebreak ? "<br>" : "");
}

var checking = null;

function startChecking() {
  document.getElementById("log").hidden = false;
  clearLogs();
  document.getElementById("pay").disabled = "disabled";
  if (checking) removeTimeout(checking);
  logLine("Checking payment status...");
  checking = setInterval(() => {
    logLine("Checking payment status...");
  }, 2000);
}

function stopChecking(json) {
  console.log(json);
  if (checking) clearTimeout(checking);
  if (json.status == "completed") {
    let v = json.value;
    logLine("Created: " + new Date(v.created * 1000).toLocaleString());
    logLine("Status: " + v.payment_status);
    logLine("Currency: " + v.currency);
    logLine("Amount: " + v.amount_total / 100);
    logLine("Reference id: " + v.client_reference_id);
  }
  if (json.status == "failed") {
    logLine(json.value);
  }
  logLine(
    "<br/><center><a id='restart'>Clear logs and try again</a></center>",
    false,
  );
  document.getElementById("restart").onclick = () => {
    console.log("restart");
    window.history.replaceState(
      {},
      document.title,
      window.location.pathname + window.location.hash,
    );
    document.getElementById("log").hidden = "hidden";
    document.getElementById("restart").hidden = "hidden";
    document.getElementById("pay").disabled = false;
  };
}

async function fetchSessionStatus(session_id) {
  try {
    const response = await fetch(`${backendURL}/checkout/${session_id}`);
    if (response.ok) {
      const data = await response.json();
      if (data.status == "checking") {
        setTimeout(() => {
          fetchSessionStatus(session_id);
        }, 500);
      } else {
        stopChecking(data);
      }
    } else {
      stopChecking({
        status: "failed",
        value: "Error: " + response.statusText,
      });
    }
  } catch (err) {
    stopChecking({ status: "failed", value: "Error: " + err });
  }
}

function start() {
  document.getElementById("pay").onclick = () => {
    window.location.href =
      "https://buy.stripe.com/test_7sY3cwg5y8k20Yb1P29oc01";
  };
  const currentUrl = window.location.href;
  const params = new URLSearchParams(new URL(currentUrl).search);
  const session_id = params.get("checkout_session_id");
  if (session_id) {
    console.log("session_id", session_id);
    startChecking();
    fetchSessionStatus(session_id);
  }
}

start();
