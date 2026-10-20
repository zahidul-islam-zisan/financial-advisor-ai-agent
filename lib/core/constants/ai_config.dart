class AiConfig {
  /// Default Gemini API Key.
  /// You can get a 100% FREE API key from Google AI Studio:
  /// https://aistudio.google.com/app/apikey
  /// 
  /// Paste your API key here or enter it inside the app via the AI Assistant screen settings!
  static String defaultGeminiApiKey = "";

  /// Active runtime API key (can be changed from within the app)
  static String activeApiKey = defaultGeminiApiKey;

  /// Gemini model name (gemini-2.5-flash with function calling support)
  static const String modelName = "gemini-2.5-flash";

  /// System instructions for the financial AI assistant
  static const String systemInstruction = """
You are "Pulse AI", an intelligent, friendly, and expert personal financial advisor and assistant inside the ExpensePulse app.
Your goals are:
1. Help the user track expenses, understand their spending patterns, and maintain a healthy budget.
2. Provide actionable, practical financial tips (e.g. 50/30/20 rule, emergency funds, debt reduction, saving strategies).
3. If the user's financial snapshot or recent transactions are provided in the prompt, analyze that specific data carefully to give personalized insights, category breakdowns, and advice.
4. Keep answers concise, clear, and well-structured using bullet points and emojis where helpful.
5. If the user asks about topics unrelated to finance, budgeting, expenses, or personal improvement, politely redirect them back to financial health and expense management.
""";

  /// Predefined quick questions for the user to tap
  static const List<String> quickSuggestions = [
    "📊 How am I spending my money?",
    "💡 Give me tips to save money",
    "🎯 How does the 50/30/20 budget work?",
    "💰 Where can I cut unnecessary expenses?",
    "📉 Help me plan my monthly budget",
  ];
}
