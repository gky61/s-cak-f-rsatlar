const { GoogleGenerativeAI } = require('@google/generative-ai');

// API Key from env.yaml
const GEMINI_API_KEY = "AIzaSyCAxNjruy70BhZedYaBZdm_mSpUHsR3Yr0";

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

async function listModels() {
  try {
    console.log("Fetching available models...");
    const modelResponse = await genAI.getGenerativeModel({ model: "gemini-1.5-flash" }); 
    // Actually there isn't a direct listModels on the instance, usually it's on the class or via a manager?
    // Wait, in the Node SDK:
    // It doesn't seem to have a direct listModels method exposed easily in the main entry for all versions.
    // But we can try to just generate content with a simple prompt to test the key.
    
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });
    const result = await model.generateContent("Hello");
    console.log("Response:", result.response.text());
    console.log("SUCCESS: gemini-pro is working with this key!");
    
  } catch (error) {
    console.error("ERROR:", error.message);
    if (error.response) {
        console.error("Error details:", JSON.stringify(error.response, null, 2));
    }
  }
}

listModels();