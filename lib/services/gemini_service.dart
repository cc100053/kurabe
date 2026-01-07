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
  // The prompt below defines exactly what fields we look for (name, price, etc).
  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    if (_apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY が設定されていません');
    }

    final bytes = await imageFile.readAsBytes();
    final mimeType = _detectMimeType(imageFile.path);
    const prompt = '''
# Role
You are a **Japanese Retail OCR Specialist**. Your task is to extract structured product data from images of Japanese supermarket price tags. You are robust against "Pop-tai" fonts, handwritten discount stickers, and complex layouts.

# Task
Analyze the provided image and extract the following data points into a strict JSON format.

# Extraction Rules

## 1. Product Name (`product_name`)
* **Goal**: Extract the specific core product name (e.g., "青森県産 サンふじりんご").
* **Noise Removal**: Remove marketing fluff, adjectives, or generic headers.
    * *Remove*: "広告の品" (Ad item), "お買い得" (Bargain), "旬の" (Seasonal), "本日限り" (Today only), "超特価" (Super Special).
    * *Keep*: Brand names (e.g., "日清", "明治") and flavor variants.
* **Text Cleaning**: Remove any non-product text like "100g当り" or pack counts.

## 2. Price Logic (`raw_price`)
* **Target**: Extract the **Visual Master Price** (the largest, most prominent number on the tag).
* **Format**: Integer only. Remove symbols like "¥", "円", "," (commas), or decimal points.
* **Context**: In Japan, this is usually the `本体価格` (Price without tax), but simply extract the number that the user would visibly identify as "The Price."

## 3. Discount Logic (`discount_info`)
* Scan the image for red/yellow stickers or crossed-out prices.
* **`type`**: 
    * "percentage" (if text contains %, 割, 半額).
    * "fixed_amount" (if text contains 円引, 引き).
    * "none" (if no discount found).
* **`value`**: 
    * If "半額" (Half Price) -> Set value to `50` (implying 50%).
    * If "2割引" or "20% OFF" -> Set value to `20`.
    * If "30円引" -> Set value to `30`.
    * If "none" -> Set value to `0`.

## 4. Price Type (`price_type`)
* **"clearance"**: If a discount sticker (半額/割引/値下) is physically attached to the product/tag.
* **"promo"**: If the tag background is Red/Yellow or says "広告の品", "特売", "Sale".
* **"standard"**: Standard white/plain tags.

## 5. Category Classification (`category`)
Classify into **EXACTLY ONE** of these 18 tags. 
**Priority Rule**: If an item fits multiple categories, pick the one **highest** in this priority list:

1.  **お酒** (Matches: Beer, Sake, Chu-hi, Wine, Whiskey - regardless of section)
2.  **惣菜** (Matches: Bento, Croquette, Tempura, Fried items, Onigiri in deli section)
3.  **冷凍食品** (Matches: ANY frozen item, even if it is frozen noodles or frozen meat)
4.  **飲料** (Matches: Water, Tea, Coffee, Soda, Juice)
5.  **インスタント** (Matches: Cup Noodles, Retort Pouches/Curry)
6.  **お菓子** (Matches: Chips, Chocolate, Gum, Snacks)
7.  **豆腐・納豆・麺** (Matches: Tofu, Natto, Fresh Udon/Soba/Ramen, Konjac, Kimchi)
8.  **パン** (Bread, Sandwiches)
9.  **乳製品** (Milk, Cheese, Yogurt, Butter)
10. **卵** (Eggs)
11. **米・穀物** (Rice, Cereal)
12. **調味料** (Sauces, Oil, Spices, Miso)
13. **精肉** (Fresh Meat, Ham, Bacon, Sausage)
14. **鮮魚** (Fresh Fish, Sashimi, Seafood)
15. **野菜** (Vegetables, Salads)
16. **果物** (Fruits)
17. **日用品** (Non-food items, Toilet paper, Detergent)
18. **その他** (Anything else)

# Output Format
Return **ONLY** valid JSON. Do not include markdown code fences (```json).

{
  "product_name": "String",
  "raw_price": Integer,
  "quantity": 1,
  "discount_info": { 
    "type": "percentage" | "fixed_amount" | "none", 
    "value": Integer 
  },
  "price_type": "clearance" | "promo" | "standard",
  "category": "String"
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
