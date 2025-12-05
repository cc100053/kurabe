# OCR Logic Overview

This file captures the current heuristics for price and product detection so we can refine them later.

## Price Detection
- **Block logging:** Every detected text block logs `[OCR RAW] Text: "...", Height, Top`.
- **Filtering:** Ignore percent values (`%`/`％`), long strings (>7 chars), weight/volume hints (`kg`, `g`, `ml`), and year-like dates without currency symbols. Discard alphabet-contaminated prices unless they start with `No.`.
- **Discount context:** If any block contains discount keywords (`値下`, `値下げ`, `引`, `割引`), nearby number blocks get a large score bonus.
- **Scoring:** Base score is block height; +10 if it has currency symbol; +100 if near discount label. Highest score wins. Parsed number uses the largest numeric token from the chosen block.
- **Tax assumption:** Detected price is assumed tax-excluded; price field set to raw value, tax toggle off, tax rate default 8% (final price shown via UI).

## Product Name Detection
- **Spatial rule:** Only consider blocks above the price; ignore if gap from price >300px or <10px (too close to price metadata).
- **Blacklist:** Skip marketing/price words (`お買得`, `広告の品`, `超目玉`, `特売`, `おすすめ`, `cgc`, `本体価格`, `税込`, `税抜`, `割引`, `値引`, `半額`, `円`, `¥`, `価格`, `値段`).
- **Quantity/spec filter:** Skip if it matches `^[0-9]+.*(g|ml|L|kg|mm|cm|袋|入|切|枚|尾|点|個)$`.
- **Language heuristic:** If length < 10 and contains no Japanese chars (Hiragana/Katakana/Kanji), discard.
- **Symbol noise:** Skip if it contains `|`, `★`, or ends with `:`.
- **Scoring:** Score = block height + proximity bonus + Kana/Kanji bonus. Proximity bonus favors gaps 20–200px above price; Kana/Kanji adds +50. Highest score wins.
- **Fallback:** If no candidate survives, fall back to the previous text-based extractor.
