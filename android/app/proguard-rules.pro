# ML Kit's bundled non-Latin language packs (Chinese, Devanagari, Japanese,
# Korean) reference com.google.mlkit.vision.text.internal.TextRecognizerTask,
# which is not present in the Latin text-recognition AAR. PillPaatha only uses
# Latin script recognition, so those code paths are never executed; this rule
# lets R8 proceed without the missing class.
-dontwarn com.google.mlkit.vision.text.internal.TextRecognizerTask
