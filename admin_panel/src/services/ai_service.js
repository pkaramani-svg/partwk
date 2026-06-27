export const generateStudyMaterials = async (summaryText, targetLanguage) => {
  const apiKey = import.meta.env.VITE_OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OpenAI API key not found. Please add VITE_OPENAI_API_KEY to your .env file in the admin_panel directory.");
  }

  const prompt = `
You are an expert educational content creator. I will provide you with a book summary.
Based on the summary, generate 5 flashcards and 5 multiple-choice quiz questions.
You MUST write all content ONLY in the following language code: ${targetLanguage.toUpperCase()} (e.g. EN for English, KU for Kurdish Sorani, AR for Arabic). Do NOT provide translations in other languages.

Output EXACTLY in the following JSON format without any markdown blocks or extra text:
{
  "flashcards": [
    {
      "id": "fc1",
      "front": "Question in target language",
      "back": "Answer in target language"
    }
  ],
  "quizzes": [
    {
      "id": "q1",
      "questionText": "Question in target language",
      "choices": ["Choice A", "Choice B", "Choice C"],
      "correctOptionIndex": 0
    }
  ]
}

Book Summary:
${summaryText}
`;

  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: "gpt-4o",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7,
        response_format: { type: "json_object" }
      })
    });

    if (!response.ok) {
      const err = await response.json();
      throw new Error(err.error?.message || "Failed to generate AI content");
    }

    const data = await response.json();
    const resultJson = JSON.parse(data.choices[0].message.content);
    return resultJson;
  } catch (error) {
    console.error("AI Generation Error:", error);
    throw error;
  }
};
