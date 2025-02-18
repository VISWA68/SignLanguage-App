from flask import Flask, request, jsonify, send_file
import moviepy.editor as mp
from moviepy.editor import VideoFileClip, concatenate_videoclips
import os
from datetime import datetime
import uuid 

app = Flask(__name__)

def generate_filename():
    unique_id = uuid.uuid4()
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"final_combined_video_{unique_id}_{timestamp}.mp4"

def merge_letter_videos(word, assets_folder):
    letter_clips = []
    for letter in word:
        letter_lower = letter.lower()
        letter_video_path = os.path.join(assets_folder, f'{letter_lower}.mp4')
        if os.path.isfile(letter_video_path):
            letter_clip = VideoFileClip(letter_video_path)
            letter_clips.append(letter_clip)
        else:
            print(f"No video found for letter: {letter_lower}")
    if not letter_clips:
        print("No valid videos found for the word.")
        return None
    final_clip = concatenate_videoclips(letter_clips)
    return final_clip

def merge_word_videos(words, assets_folder):
    video_clips = []
    for word in words:
        word_lower = word.lower()
        word_video_path = os.path.join(assets_folder, f'{word_lower}.mp4')
        if os.path.isfile(word_video_path):
            video_clip = VideoFileClip(word_video_path)
            video_clips.append(video_clip)
        else:
            print(f"No video found for word: {word_lower}")
            print(f"Splitting '{word}' into letters...")
            letter_video = merge_letter_videos(word, assets_folder)
            if letter_video is not None:
                video_clips.append(letter_video)
    if not video_clips:
        print("No valid videos found.")
        return None
    final_clip = concatenate_videoclips(video_clips)
    return final_clip

@app.route('/text', methods=['POST'])
def generate_combined_video():
    data = request.get_json()
    text = data.get('text')
    if not text:
        return jsonify({'error': 'Invalid request. Missing required parameter: text'}), 400

    assets_folder = 'D:/final/final_app/python/assets1'
    words = text.split()
    if not words:
        return jsonify({'error': 'Please enter a valid sentence.'}), 400

    video = merge_word_videos(words, assets_folder)
    if video is None:
        return jsonify({'error': 'No valid videos found.'}), 400

    final_video_path = generate_filename()
    video.write_videofile(final_video_path, codec="libx264")

    return send_file(final_video_path, as_attachment=True, download_name='final_combined_video.mp4')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
