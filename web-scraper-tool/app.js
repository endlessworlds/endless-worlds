import express from 'express';
import fetch from 'node-fetch';
import dotenv from 'dotenv';
import axios from 'axios';
import * as cheerio from 'cheerio';
import fs from 'fs';

dotenv.config();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const DEBUG_FILE = './debug_scrape.txt';

/* ----------------------------------------
   UNIVERSAL SEARCH & SCRAPE
-----------------------------------------*/
async function scrapeUniversal(topic) {
    try {
        fs.writeFileSync(DEBUG_FILE, `--- SCRAPE LOG FOR TOPIC: ${topic} ---\n\n`, 'utf8');

        // Use DuckDuckGo HTML for better scraping compatibility
        const searchUrl = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(topic + " quiz questions and answers")}`;
        console.log(`\n--- Searching for: ${topic} ---`);

        const { data: searchHtml } = await axios.get(searchUrl, {
            headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" },
            timeout: 5000
        });

        const $search = cheerio.load(searchHtml);
        let targetUrl = '';

        $search('.result__a').each((i, el) => {
            const href = $search(el).attr('href');
            if (href && !targetUrl) {
                const match = href.match(/uddg=([^&]+)/);
                targetUrl = match ? decodeURIComponent(match[1]) : href;
            }
        });

        if (!targetUrl) throw new Error("No search results found.");

        console.log(`Scraping: ${targetUrl}`);
        fs.appendFileSync(DEBUG_FILE, `SOURCE URL: ${targetUrl}\n\n`);

        const { data: pageHtml } = await axios.get(targetUrl, {
            headers: { "User-Agent": "Mozilla/5.0" },
            timeout: 5000
        });

        const $ = cheerio.load(pageHtml);
        $('script, style, nav, footer, iframe, ads').remove();

        let rawText = $('p, li, span, h1, h2, h3').text().replace(/\s+/g, ' ').trim();
        const cleanedText = rawText.substring(0, 5000);

        fs.appendFileSync(DEBUG_FILE, cleanedText);
        return cleanedText;

    } catch (err) {
        const errorMsg = `Scraping failed (${err.message}). Falling back to LLM internal knowledge.`;
        console.warn(errorMsg);
        fs.appendFileSync(DEBUG_FILE, `\n\nFALLBACK TRIGGERED: ${errorMsg}`);
        return null; // Return null to indicate fallback is needed
    }
}

/* ----------------------------------------
   API ENDPOINT
-----------------------------------------*/
app.post('/generate-riddle', async (req, res) => {
    try {
        const { difficulty, topic } = req.body;
        if (!difficulty || !topic) return res.status(400).json({ error: "Missing difficulty or topic" });

        const webData = await scrapeUniversal(topic);
        
        // Dynamic Prompt logic based on whether webData exists
        const sourceContext = webData 
            ? `SOURCE MATERIAL FROM WEB:\n${webData}` 
            : `No web data available. Use your internal knowledge about "${topic}".`;

        const prompt = `
        SYSTEM: You are a technical riddle creator. 
        ${sourceContext}

        TASK:
        1. Create a riddle about "${topic}". ${webData ? "Base it on the SOURCE MATERIAL provided." : ""}
        2. The "solution" MUST be a single word.
        3. Generate 4 "options" for the user to choose from.
        4. CRITICAL: The "solution" MUST be exactly one of the items in the "options" array.
        5. Difficulty: ${difficulty}.
        
        OUTPUT STRICT JSON:
        {
          "riddle": "string",
          "options": ["opt1", "opt2", "opt3", "opt4"],
          "solution": "string",
          "hints": ["hint1", "hint2", "hint3", "hint4"],
          "fact_reference": "Short sentence explaining the fact used",
          "source": "${webData ? 'web' : 'internal_knowledge'}"
        }`;

        const groqResponse = await fetch("https://api.groq.com/openai/v1/chat/completions", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${process.env.GROQ_API_KEY}`
            },
            body: JSON.stringify({
                model: "llama-3.1-8b-instant",
                messages: [{ role: "user", content: prompt }],
                temperature: 0.5,
                response_format: { type: "json_object" }
            })
        });

        const data = await groqResponse.json();
        const content = data.choices[0].message.content;
        
        // Sanitize to prevent JSON parse errors from control characters
        const finalRiddle = JSON.parse(content.replace(/[\x00-\x1F\x7F-\x9F]/g, ""));

        fs.appendFileSync(DEBUG_FILE, `\n\n--- LLM FINAL OUTPUT ---\n${JSON.stringify(finalRiddle, null, 2)}`);
        
        console.log(`Riddle generated via ${finalRiddle.source}.`);
        return res.status(200).json(finalRiddle);

    } catch (err) {
        console.error("Endpoint Error:", err.message);
        return res.status(500).json({ error: "Internal Server Error" });
    }
});

app.listen(PORT, () => {
    console.log(`Server running: http://localhost:${PORT}`);
});