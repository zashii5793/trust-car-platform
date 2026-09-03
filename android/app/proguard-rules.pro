# google_mlkit_text_recognition references all of its optional script
# recognizers (Chinese, Devanagari, Japanese, Korean) from a single entry
# point. This app only uses the Latin (bundled) and Japanese (added as an
# explicit dependency) models, so silence R8 about the remaining scripts whose
# classes are intentionally not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.korean.**
