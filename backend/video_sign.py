from flask import Flask, request, jsonify, send_file
import moviepy.editor as mp
from moviepy.editor import VideoFileClip, concatenate_videoclips, clips_array
import os
import speech_recognition as sr
import tempfile

app = Flask(__name__)

def merge_letter_videos(word, assets_folder):
    letter_clips = []
    for letter in word:
        letter_lower = letter.lower()
        letter_video_path = os.path.join(assets_folder, f"{letter_lower}.mp4")
        if os.path.isfile(letter_video_path):
            letter_clip = VideoFileClip(letter_video_path)
            letter_clips.append(letter_clip)
        else:
            print(f"No video found for letter: {letter_lower}")
    if not letter_clips:
        return None
    final_clip = concatenate_videoclips(letter_clips)
    return final_clip

def merge_word_videos(words, assets_folder):
    video_clips = []
    for word in words:
        word_lower = word.lower()
        word_video_path = os.path.join(assets_folder, f"{word_lower}.mp4")
        if os.path.isfile(word_video_path):
            video_clip = VideoFileClip(word_video_path)
            video_clips.append(video_clip)
        else:
            letter_video = merge_letter_videos(word, assets_folder)
            if letter_video is not None:
                video_clips.append(letter_video)
    if not video_clips:
        return None
    final_clip = concatenate_videoclips(video_clips)
    return final_clip

def extract_audio_as_text(video_path):
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_audio_file:
            temp_audio_path = temp_audio_file.name

        video = mp.VideoFileClip(video_path)
        audio = video.audio
        audio.write_audiofile(temp_audio_path)
        r = sr.Recognizer()
        with sr.AudioFile(temp_audio_path) as source:
            audio_data = r.record(source)
            audio_text = r.recognize_google(audio_data)
        os.remove(temp_audio_path)
        return audio_text
    except Exception as e:
        print(f"Error processing video: {e}")
        return None

@app.route("/video_sign", methods=["POST"])
def generate_combined_video():
    video_folder = "video"  
    if not os.path.exists(video_folder):
        os.makedirs(video_folder) 

    if 'video' not in request.files:
        return jsonify({"error": "No video file provided"}), 400

    video_file = request.files['video']
    video_file_path = os.path.join(video_folder, "uploaded_video.mp4")
    video_file.save(video_file_path)

    extracted_text = extract_audio_as_text(video_file_path)
    if extracted_text is None:
        return jsonify({"error": "Failed to extract audio text."}), 500

    assets_folder = "D:/final/final_app/python/assets1"
    words = extracted_text.split()
    if not words:
        return jsonify({"error": "No valid words found in the audio."}), 400

    video = merge_word_videos(words, assets_folder)
    if video is None:
        return jsonify({"error": "No valid videos found."}), 400

    continuous_video_path = os.path.join(video_folder, "output_continuous_video.mp4")
    video.write_videofile(continuous_video_path, codec="libx264")

    uploaded_video = VideoFileClip(video_file_path)
    uploaded_video = uploaded_video.resize(height=video.h)

    final_video = clips_array([[uploaded_video, video]])
    final_video_path = os.path.join(video_folder, "final_combined_video.mp4")
    final_video.write_videofile(final_video_path, codec="libx264")

    return send_file(final_video_path, as_attachment=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)
