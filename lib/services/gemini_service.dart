import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path/path.dart' as p;

class GeminiService {
  GeminiService({String? apiKey})
    : _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
      _model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
      );

  final String _apiKey;
  final GenerativeModel _model;

  // TODO: Scanning Logic - This method sends the image to Gemini to extract product details.
  // The prompt below defines exactly what fields we look for (name, price, quantity, etc).
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    if (_apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY が設定されていません');
    }

    final bytes = await imageFile.readAsBytes();
    final mimeType = _detectMimeType(imageFile.path);
    const prompt = '''
Analyze this image of a Japanese supermarket price tag.
Extract the product name (ignore marketing fluff or pack counts) and the `raw_price` (the largest price printed on the tag).
Look for `quantity` indicators (e.g., "3点", "3本", "3個", "pair") and default to 1 when uncertain.
Look for discount stickers (e.g., "30% Off", "半額", "20円引") and extract the discount type and value.
Classify `price_type`: "clearance" when discount stickers are present, "promo" for red promotional tags/ads, otherwise "standard".
Classify the product into EXACTLY one of these 18 tags (Japanese text must match): [野菜, 果物, 精肉, 鮮魚, 惣菜, 卵, 乳製品, 豆腐・納豆・麺, パン, 米・穀物, 調味料, インスタント, 飲料, お酒, お菓子, 冷凍食品, 日用品, その他].
- Strict Rules:
- If item is Beer, Sake, or Chu-hi -> "お酒".
- If item is Water, Tea, Coffee, Juice, or Cola -> "飲料".
- If item is Tofu, Natto, Kimchi, Fresh Udon/Soba/Konjac -> "豆腐・納豆・麺".
- If item is Cup Noodle or retort/instant meal -> "インスタント".
- If item is Bento, croquette, karaage, or fried deli foods -> "惣菜".
Use "その他" if none fit.
Return ONLY valid JSON with this structure:
{
  "product_name": "String",
  "raw_price": 298,
  "quantity": 3,
  "discount_info": { "type": "percentage", "value": 30 },
  "price_type": "clearance",
  "category": "惣菜"
}
''';

    final response = await _model.generateContent([
      Content.multi([TextPart(prompt), DataPart(mimeType, bytes)]),
    ]);

    final responseText = response.text;
    if (responseText == null || responseText.trim().isEmpty) {
      throw const FormatException('Geminiからのレスポンスが空です');
    }

    final cleanedJson = _extractJson(responseText);
    final decoded = json.decode(cleanedJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('レスポンスJSONがオブジェクトではありません');
    }
    return decoded;
  }

  String _extractJson(String raw) {
    var text = raw.trim();
    final fencedMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      multiLine: true,
    ).firstMatch(text);
    if (fencedMatch != null && fencedMatch.groupCount >= 1) {
      text = fencedMatch.group(1)!.trim();
    }
    if (text.toLowerCase().startsWith('json')) {
      text = text.substring(4).trim();
    }
    text = text.replaceAll(RegExp(r'^```|```$'), '').trim();
    return text;
  }

  String _detectMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
