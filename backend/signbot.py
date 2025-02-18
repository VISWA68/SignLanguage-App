from flask import Flask, request, jsonify
import time
import urllib.request
import cv2
import mediapipe as mp
import numpy as np
import google.generativeai as genai
import google.ai.generativelanguage as glm
from dotenv import load_dotenv
import os
from tensorflow.keras.models import load_model
from moviepy.editor import VideoFileClip, concatenate_videoclips, TextClip, CompositeVideoClip
import tempfile
from firebase_admin import credentials, initialize_app, storage, firestore
import uuid

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "D:/Helping-Hands/backend/helping-hands-834db-firebase-adminsdk-wrwm1-7f8219f13a.json"

app = Flask(__name__)

cred = credentials.Certificate(
    "D:/Helping-Hands/backend/helping-hands-834db-firebase-adminsdk-wrwm1-7f8219f13a.json")
initialize_app(cred, {'storageBucket': 'helping-hands-834db.appspot.com'})
bucket = storage.bucket()
db = firestore.client()

mp_holistic = mp.solutions.holistic  
mp_drawing = mp.solutions.drawing_utils
model = None  
actions = np.array(['hello', 'thankyou'])  
def load_model_and_actions():
    global model
    model = load_model('D:/Helping-Hands/backend/action.h5')

def upload_video_to_firebase(video_path, destination_path):
    try:
        blob = bucket.blob(destination_path)
        blob.upload_from_filename(video_path)
      
        blob.make_public()
        print(f"Video uploaded to {blob.public_url}")
        return blob.public_url
    except Exception as e:
        print(f"Error uploading video - {e}")
        return None

def download_http_video(url, destination):
    try:
        with urllib.request.urlopen(url) as response, open(destination, 'wb') as out_file:
            chunk_size = 8192
            while True:
                chunk = response.read(chunk_size)
                if not chunk:
                    break
                out_file.write(chunk)
        print(f"Download successful. Content saved to {destination}")
    except Exception as e:
        print(f"Error: {e}")

def generate_video(extracted_text, assets_folder):
    words = extracted_text.split()
    video_clips = []

    for word in words:
        word_lower = word.lower()
        word_video_path = os.path.join(assets_folder, f'{word_lower}.mp4')
        if os.path.isfile(word_video_path):
            video_clip = VideoFileClip(word_video_path)
            video_clips.append(video_clip)

    if not video_clips:
        return None

    final_clip = concatenate_videoclips(video_clips)
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_video_file:
        temp_video_path = temp_video_file.name
        final_clip.write_videofile(temp_video_path, codec="libx264")
    
    return temp_video_path

def generate_final_combined_video(video_text, assets_folder):
    clips = []
    words = video_text.split()

    for word in words:
        word_lower = word.lower()
        word_video_path = os.path.join(assets_folder, f'{word_lower}.mp4')
        if os.path.isfile(word_video_path):
            video_clip = VideoFileClip(word_video_path)
            clips.append(video_clip)
    
    if not clips:
        return None
    
    final_clip = concatenate_videoclips(clips, method="compose")
    with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_video_file:
        temp_video_path = temp_video_file.name
        final_clip.write_videofile(temp_video_path, codec="libx264")
    
    return temp_video_path

def mediapipe_detection(image, model):
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image.flags.writeable = False
    results = model.process(image)
    image.flags.writeable = True
    image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
    return image, results

@app.route('/bot', methods=['POST'])
def bot():
    sequence = []
    sentence = []
    predictions = []
    threshold = 0.5
    data = request.get_json()
    video_url = data.get('url')
    destination_file = "sample_video.mp4"
    download_http_video(video_url, destination_file)

    cap = cv2.VideoCapture(destination_file)
    with mp_holistic.Holistic(min_detection_confidence=0.5, min_tracking_confidence=0.5) as holistic:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            image, results = mediapipe_detection(frame, holistic)
            draw_styled_landmarks(image, results)
            keypoints = extract_keypoints(results)
            sequence.append(keypoints)
            sequence = sequence[-30:]

            if len(sequence) == 30:
                res = model.predict(np.expand_dims(sequence, axis=0))[0]
                predictions.append(np.argmax(res))
                if np.unique(predictions[-10:])[0] == np.argmax(res):
                    if res[np.argmax(res)] > threshold:
                        if len(sentence) > 0:
                            if actions[np.argmax(res)] != sentence[-1]:
                                sentence.append(actions[np.argmax(res)])
                        else:
                            sentence.append(actions[np.argmax(res)])
                if len(sentence) > 5:
                    sentence = sentence[-5:]

    cap.release()
    load_dotenv()
    API_KEY = os.environ.get("AIzaSyBtMdFsAHQmcYLZ_A-guBukyF-lK1zsy8k")
    genai.configure(api_key=API_KEY)
    modeled = genai.GenerativeModel("gemini-1.5-pro")
    chat = modeled.start_chat(history=[])
    response = chat.send_message(' '.join(sentence))
    video_text = response.text
    if video_text:
        assets_folder = 'D:/Helping-Hands/backend/assets1'
        sign_path = generate_final_combined_video(video_text, assets_folder)
        if sign_path:
            unique_filename = f"video_{uuid.uuid4()}.mp4"
            final_video_url = upload_video_to_firebase(sign_path, unique_filename)
            doc_ref = db.collection('sign_bot').add({
                'uploaded_video': video_url,
                'final_video_url': final_video_url,
            })
            response = {
                'message': video_text,
                'final_video_url': final_video_url,
            }
            print(video_text)
            print(final_video_url)
            return jsonify(response), 200
    return jsonify({'message': 'Error processing video'}), 500

def draw_styled_landmarks(image, results):
    mp_drawing.draw_landmarks(image, results.pose_landmarks, mp_holistic.POSE_CONNECTIONS,
                              mp_drawing.DrawingSpec(color=(80, 22, 10), thickness=2, circle_radius=4),
                              mp_drawing.DrawingSpec(color=(80, 44, 121), thickness=2, circle_radius=2))
    mp_drawing.draw_landmarks(image, results.left_hand_landmarks, mp_holistic.HAND_CONNECTIONS,
                              mp_drawing.DrawingSpec(color=(121, 22, 76), thickness=2, circle_radius=4),
                              mp_drawing.DrawingSpec(color=(121, 44, 250), thickness=2, circle_radius=2))
    mp_drawing.draw_landmarks(image, results.right_hand_landmarks, mp_holistic.HAND_CONNECTIONS,
                              mp_drawing.DrawingSpec(color=(245, 117, 66), thickness=2, circle_radius=4),
                              mp_drawing.DrawingSpec(color=(245, 66, 230), thickness=2, circle_radius=2))

def extract_keypoints(results):
    pose = np.array([[res.x, res.y, res.z, res.visibility] for res in results.pose_landmarks.landmark]).flatten() \
        if results.pose_landmarks else np.zeros(33 * 4)
    lh = np.array([[res.x, res.y, res.z] for res in results.left_hand_landmarks.landmark]).flatten() \
        if results.left_hand_landmarks else np.zeros(21 * 3)
    rh = np.array([[res.x, res.y, res.z] for res in results.right_hand_landmarks.landmark]).flatten() \
        if results.right_hand_landmarks else np.zeros(21 * 3)
    return np.concatenate([pose, lh, rh])

load_model_and_actions()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=4000)
