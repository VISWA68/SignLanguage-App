import sys
import io
from transformers import MarianMTModel, MarianTokenizer

# Set the standard output encoding to UTF-8
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
00000
# Load the MarianMT model and tokenizer for English to Hindi translation
model_name = 'Helsinki-NLP/opus-mt-en-hi'
model = MarianMTModel.from_pretrained(model_name)
tokenizer = MarianTokenizer.from_pretrained(model_name)

# Define the source text (English)
src_texts = ["hello"]
654432
# Tokenize the source text and translate it
translated = model.generate(**tokenizer(src_texts, return_tensors="pt", padding=True))

# Decode the translated text to Hindi
tgt_texts = [tokenizer.decode(t, skip_special_tokens=True) for t in translated]

# Print the translated text (Hindi)
print(tgt_texts[0])  # Output will be in Hindi
