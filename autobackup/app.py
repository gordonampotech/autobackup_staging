from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
from datetime import datetime, timedelta
import requests

app = Flask(__name__)
CORS(app)

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
    
@app.route('/manualBackup', methods=['GET'])
def manualBackup():
    SUPERVISOR_TOKEN = get_supervisor_token()
    SUPERVISOR_API = "http://supervisor/backups/new/full"
    FILENAME = "backup_restored"
    
    payload = {"name": FILENAME}
    headers = {
        "Authorization": f"Bearer {SUPERVISOR_TOKEN}",
        "Content-Type": "application/json"
    }

    # Create a new backup via Supervisor API
    response = requests.post(SUPERVISOR_API, headers=headers, json=payload)
    backup_data = response.json()
    backup_id = backup_data.get('data', {}).get('slug')

    if not backup_id:
        return jsonify({"error": "Failed to create backup.", "backup_data": backup_data}), 500

    # Define path where to save the backup file
    filename = "backup_restored.tar"
    BACKUP_PATH = "/tmp/"
    backup_file_path = os.path.join(BACKUP_PATH, filename)

    # Download the backup
    download_url = f"http://supervisor/backups/{backup_id}/download"
    with requests.get(download_url, headers=headers, stream=True) as r:
        r.raise_for_status()
        with open(backup_file_path, 'wb') as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)

    # Get file size in MB
    size = os.path.getsize(backup_file_path) / (1024 * 1024)
    # Timestamps
    sleep_start = int(datetime.now().timestamp())
    sleep_end = int((datetime.now() + timedelta(days=10)).timestamp())

    # Backup information JSON
    mac_address = get_mac_address()
    backup_info = {
        "mac_addr": mac_address,
        "filename": filename,
        "size": size,
        "sleep_start": sleep_start,
        "sleep_end": sleep_end
    }

    # Send backup information to the remote server
    info_response = requests.post("http://13.250.103.69:5000/uploadBackupDetails", json=backup_info)
    if not info_response.ok:
        return jsonify({"response": "info_response failed"}), 500
    # Send backup file to the remote server
    files = {'file': (filename, open(backup_file_path, 'rb'))}
    file_response = requests.post("http://13.250.103.69:5000/uploadBackupFile", files=files, data={"mac_addr": backup_info["mac_addr"]})
    if not file_response.ok:
        return jsonify({"response": "file_response failed"}), 500

    return backup_info, 200

def get_mac_address():
    try:
        with open('/tmp/mac_address.txt', 'r') as file:
            mac_address = file.read().strip()
            return mac_address
    except FileNotFoundError:
        return None
    
def get_supervisor_token():
    supervisor_token = os.getenv('SUPERVISOR_TOKEN')
    if supervisor_token:
        return f'Supervisor Token: {supervisor_token}'
    else:
        return 'Supervisor Token not found.'

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')