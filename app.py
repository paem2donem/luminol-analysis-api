import os
import time
import sys
import cv2
import numpy as np
import matplotlib
matplotlib.use('Agg') # Sunucu ortamı için GUI kapatma
import matplotlib.pyplot as plt
import flask # Sonsuz döngüyü engellemek için doğrudan import
from flask import Flask, request, jsonify
from flask_cors import CORS  
import matplotlib
matplotlib.use('Agg')  # RAM dostu, arayüzsüz grafik motoru

app = Flask(__name__)
CORS(app)  # Tüm tarayıcılardan gelen isteklere izin verir (CORS engeli baypas edilir)

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 10
plt.rcParams['axes.linewidth'] = 1.0

@app.route('/')
def home():
    return "Luminol Analiz Sunucusu Aktif!"

@app.route('/analiz', methods=['POST'])
def analiz_et():
    if 'video' not in request.files:
        return jsonify({"hata": "Videolar kisminda dosya bulunamadi."}), 400
        
    file = request.files['video']
    if file.filename == '':
        return jsonify({"hata": "Dosya secilmedi."}), 400

    video_filename = os.path.splitext(file.filename)[0]
    video_path = os.path.join(UPLOAD_FOLDER, file.filename)
    file.save(video_path)

    try:
        analysis_start = time.time()
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        
        raw_intensities = []
        timestamps = []
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret: break
            
            blue_channel = frame[:, :, 0]
            h, w = blue_channel.shape
            y1, y2 = int(h * 0.25), int(h * 0.75)
            x1, x2 = int(w * 0.25), int(w * 0.75)
            roi = blue_channel[y1:y2, x1:x2]
            
            raw_intensities.append(np.mean(roi))
            timestamps.append(len(raw_intensities) / fps)
        
        cap.release()

        raw_intensities = np.array(raw_intensities)
        timestamps = np.array(timestamps)

        baseline_frames = min(30, len(raw_intensities))
        baseline_noise = np.mean(raw_intensities[:baseline_frames])
        corrected_intensities = np.maximum(raw_intensities - baseline_noise, 0)

        peak_val = np.max(corrected_intensities)
        peak_idx = np.argmax(corrected_intensities)
        peak_time = timestamps[peak_idx]
        
        # Sürüm kısıtlamalarını aşmak için yamuk alanı formülü saf numpy ile manuel hesaplanır
        y_data = corrected_intensities
        auc_val = float(0.5 * np.sum(y_data[:-1] + y_data[1:]))

        try:
            post_peak = corrected_intensities[peak_idx:]
            post_times = timestamps[peak_idx:]
            h_idx = np.where(post_peak <= (peak_val / 2))[0][0]
            half_life = post_times[h_idx] - peak_time
        except:
            half_life = 0

        fig, ax = plt.subplots(figsize=(8, 5))
        ax.plot(timestamps, corrected_intensities, color='#000080', linewidth=1.5, label='CL Signal', zorder=2)
        ax.fill_between(timestamps, corrected_intensities, color='#000080', alpha=0.07, zorder=1)
        
        ax.axvline(x=peak_time, color='red', linestyle='--', linewidth=1, alpha=0.7, label=f'Peak T: {peak_time:.2f}s')
        ax.scatter(peak_time, peak_val, color='red', s=25, edgecolor='black', linewidth=0.5, zorder=5)

        ax.set_title(video_filename, fontsize=12, fontweight='bold', pad=15)
        ax.set_xlabel('Time (s)', fontsize=11)
        ax.set_ylabel('Mean Intensity (a.u.)', fontsize=11)
        
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.grid(True, linestyle='--', alpha=0.3, which='both')
        #ax.legend(frameon=False, fontsize=9, loc='upper right')

        graph_filename = f"{video_filename}_Q1_Analysis.png"
        graph_path = os.path.join(UPLOAD_FOLDER, graph_filename)
        plt.savefig(graph_path, dpi=300, bbox_inches='tight')
        plt.close('all')

        analysis_end = time.time()
        elapsed_total_seconds = analysis_end - analysis_start
        elapsed_minutes = int(elapsed_total_seconds // 60)
        elapsed_seconds = int(elapsed_total_seconds % 60)

        if os.path.exists(video_path):
            os.remove(video_path)

        return jsonify({
            "status": "success",
            "filename": video_filename,
            "peak_intensity_au": round(float(peak_val), 2),
            "baseline_noise_au": round(float(baseline_noise), 4),
            "time_to_peak_sec": round(float(peak_time), 2),
            "area_under_curve_auc": round(float(auc_val), 2),
            "half_life_sec": round(float(half_life), 2),
            "total_processing_time": f"{elapsed_minutes} dakika {elapsed_seconds} saniye",
            "graph_name": graph_filename
        })

    except Exception as e:
        if os.path.exists(video_path):
            os.remove(video_path)
        # Hata Önleme: Hatayı gizlemek yerine tam adını ekrana basalım
        import traceback
        hata_detayi = traceback.format_exc()
        return jsonify({"status": "error", "message": str(e), "details": hata_detayi}), 500

@app.route('/grafik/<filename>', methods=['GET'])
def grafik_getir(filename):
    graph_path = os.path.join(UPLOAD_FOLDER, filename)
    if os.path.exists(graph_path):
        # Maksimum recursion hatasını engellemek için flask.send_file adıyla çağrılır
        return flask.send_file(graph_path, mimetype='image/png')
    else:
        return jsonify({"hata": "Grafik bulunamadi."}), 404

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 10000))
    app.run(host='0.0.0.0', port=port)


