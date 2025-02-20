# Helping Hands  
_A Smart Communication App for the Hearing and Speech Impaired_  

## 📌 Overview  
Helping Hands is an innovative Flutter application with a Flask backend designed to bridge the communication gap for individuals with hearing and speech impairments. The app provides a seamless two-way communication system using sign language recognition, text, and audio translation.  

## ✨ Features  
✅ **Sign Language Generation** - Converts uploaded videos into sign language for easy communication.  
✅ **Sign Language to Text & Audio** - Translates sign language gestures into text and speech.  
✅ **Two-Way Communication** - Enables conversation between sign language users and non-sign language users.  
✅ **Offline Language Translation** - Supports multiple language translations offline using MarianMT.  
✅ **Sign Language Chatbot** - Users can input queries in sign language and receive responses in sign language.  

## 🏗️ Tech Stack  
- **Frontend:** Flutter  
- **Backend:** Flask  
- **Machine Learning:** Sign language recognition and translation models  

## 🚀 Installation & Setup  

### Prerequisites  
Ensure you have the following installed:  
- Flutter SDK  
- Python (with Flask and required dependencies)  

1. **Clone the Repository**
   ```bash
   git clone https://github.com/VISWA68/SignLanguage-App.git
   cd backend
   ```
2. **Setup the Backend**
   - Navigate to the `backend` folder.
   - Install dependencies:
     ```bash
     pip install -r requirements.txt
     ```
   - Run the server:
     ```bash
     python sign_text.py
     python text_sign.py
     python signbot.py
     python video_sign.py 
     ```

3. **Setup the Frontend**
   - Navigate to the `helping_hands` folder.
   - Install dependencies:
     ```bash
     flutter pub get
     ```
   - Run the app:
     ```bash
     flutter run
     ```
