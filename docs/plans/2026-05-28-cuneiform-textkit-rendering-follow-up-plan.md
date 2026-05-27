# Cuneiform TextKit Rendering Follow-up Plan

## Decision

Keep the MarkdownUI renderer as an opt-in spike behind `CUNEIFORM_RENDERER=native`. Do not switch the default renderer yet. The unset and unknown renderer mode must continue to use the WebView path.

## Benchmark Evidence

Native run:

- TextEdit: count=10 min=109.61ms p50=123.73ms p95=143.91ms max=143.91ms
- Cuneiform external: count=10 min=321.52ms p50=331.71ms p95=613.19ms max=613.19ms
- Cuneiform app-internal: count=10 min=213.35ms p50=220.87ms p95=226.54ms max=226.54ms

WebView run:

- TextEdit: count=10 min=112.59ms p50=124.44ms p95=134.86ms max=134.86ms
- Cuneiform external: count=10 min=439.79ms p50=454.14ms p95=513.78ms max=513.78ms
- Cuneiform app-internal: count=10 min=330.03ms p50=340.51ms p95=395.02ms max=395.02ms

TextEdit window detection used the process-visible lower-bound fallback. The native MarkdownUI path meets the `<= 550ms` external p50 gate and improves app-internal p50 versus WebView, but it misses the within-15%-of-TextEdit gate. That makes it useful as measurement evidence, not safe as the default renderer.

## TextKit Direction

Build a narrower native renderer spike using `NSTextView`, TextKit, and attributed strings generated from the existing Markdown parse path. The first target is first-visible-document speed, not full Markdown feature parity.

Initial implementation goals:

- Reuse the existing file intake, Markdown loading, and startup probe contract.
- Render headings, paragraphs, emphasis, inline code, links, lists, block quotes, and fenced code blocks with deterministic attributed string styling.
- Avoid WebView and MarkdownUI on the default-opening critical path.
- Keep the renderer selectable through an explicit environment mode until it passes the same measurement gate.

Measurement gate:

- Cuneiform TextKit external p50 is `<= 550ms`.
- Cuneiform TextKit external p50 is within 15% of TextEdit p50 in the same run.
- Cuneiform TextKit app-internal p50 is lower than the current WebView app-internal p50 for the same file.
- The smoke document renders without crashes or severe layout regressions.
