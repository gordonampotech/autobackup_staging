from flask import Flask, render_template, request, jsonify
from werkzeug.utils import secure_filename
import os

app = Flask(__name__)

@app.route('/')
def home():
    mac_address = get_mac_address()
    print("mac_addr", mac_address)
    return render_template('index.html', mac_address=mac_address)

@app.route('/storeBackup', methods=['POST'])
def storeBackup():
    print("storing backups")
    if 'file' not in request.files:
        return jsonify({'error': 'No file part in the request'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected for uploading'}), 400
    if file:
        filename = secure_filename(file.filename)
        file_path = os.path.join("/backup", filename)
        print(file_path)
        file.save(file_path)
        return jsonify({'message': 'File successfully uploaded', 'path': file_path}), 200

def get_mac_address():
    try:
        with open('/tmp/mac_address.txt', 'r') as file:
            mac_address = file.read().strip()
            return mac_address
    except FileNotFoundError:
        return None

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')