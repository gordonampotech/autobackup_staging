from flask import Flask, render_template, jsonify
from flask_cors import CORS
import os
from datetime import datetime, timedelta
import requests

app = Flask(__name__)
CORS(app)

@app.route('/')
def home():
    mac_address = get_mac_address()
    return render_template('index.html', mac_address=mac_address)

def download_backup_from_url(url, filename):
    try:
        # Make a request to the presigned URL
        response = requests.get(url)
        response.raise_for_status()  # Check if the request was successful

        # Write the content to the specified path
        file_path = os.path.join("/backup", filename)
        with open(file_path, 'wb') as file:
            file.write(response.content)

        return {"message": "File downloaded successfully"}, 200
    except requests.RequestException as e:
        return {"error": str(e)}, 500
    except Exception as e:
        return {"error": str(e)}, 500

def fetch_presigned_url(api_endpoint):
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    }
    body = {"mac_addr": get_mac_address()}
    response = requests.post(api_endpoint, headers=headers, json=body)
    if response.ok:
        data = response.json()
        presigned_url, filename = data.get('url'), data.get('filename')
        if not presigned_url or not filename:
            return {"error": "url and filename not found"}, 400
        return {"url": presigned_url, "filename": filename}, 200
    else:
        return {"response": "backup not found"}, response.status_code 

@app.route('/downloadBackup', methods=['GET'])
def download_latest_backup():
    result, status = fetch_presigned_url('https://vida.ampo.tech/downloadLatestBackup')
    if status != 200:
        return jsonify(result), status
    return jsonify(*download_backup_from_url(result['url'], result['filename']))

@app.route('/downloadPrevBackup', methods=['GET'])
def download_prev_backup():
    result, status = fetch_presigned_url('https://vida.ampo.tech/get_prev_device_backup')
    if status != 200:
        return jsonify(result), status
    return jsonify(*download_backup_from_url(result['url'], result['filename']))


@app.route('/getBackupDetails', methods=['GET'])
def getBackupDetails():
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    }
    body = {"mac_addr": get_mac_address()}
    response = requests.post('https://vida.ampo.tech/getBackupDetails', headers=headers, json=body)
    if response.ok:
        data = response.json()
        filename, size, sleep_start, sleep_end = data.get('filename'), data.get('size'), data.get('sleep_start'), data.get('sleep_end')
        if not filename or not size or not sleep_start or not sleep_end:
            return {"error": "Invalid backup details"}, 400
        return {"filename": filename, "size": size, "sleep_start": sleep_start, "sleep_end": sleep_end}, 200
    else:
        return jsonify({"response": "backup not found"}), response.status_code 
    
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
    print("manualBackup", response)
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

    print("finished downloading")
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
    info_response = requests.post("https://vida.ampo.tech/uploadBackupDetails", json=backup_info)
    print(info_response)
    if not info_response.ok:
        return jsonify({"response": "info_response failed"}), 500
    # Send backup file to the remote server
    files = {'file': (filename, open(backup_file_path, 'rb'))}
    file_response = requests.post("https://vida.ampo.tech/uploadBackupFile", files=files, data={"mac_addr": backup_info["mac_addr"]})
    print(file_response)
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