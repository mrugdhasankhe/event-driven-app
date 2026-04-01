const API_URL = "https://kdu8yqmtf2.execute-api.us-east-1.amazonaws.com/submit-review";

document.getElementById("form").addEventListener("submit", async function(e) {
  e.preventDefault();

  const name = document.getElementById("name").value;
  const email = document.getElementById("email").value;
  const portfolio = document.getElementById("portfolio").value;
  const messageDiv = document.getElementById("message");

  messageDiv.innerText = "Submitting...";

  try {
    const response = await fetch(API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        name: name,
        email: email,
        portfolio_url: portfolio
      })
    });

    const data = await response.json();

    if (response.ok) {
      messageDiv.style.color = "green";
      messageDiv.innerText = data.message;
    } else {
      messageDiv.style.color = "red";
      messageDiv.innerText = data.message || "Error occurred";
    }

  } catch (error) {
    messageDiv.style.color = "red";
    messageDiv.innerText = "Failed to connect to server";
  }
});