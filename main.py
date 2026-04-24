from fastapi import FastAPI, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import pandas as pd
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer


app = FastAPI()

# --- Chargement des ressources ---
data = pd.read_csv('music_data_cleaned.csv')
embeddings = np.load('music_embeddings.npy').astype('float32')
model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')

index = faiss.IndexFlatIP(embeddings.shape[1])
index.add(embeddings)


# 1. Route pour servir ton fichier HTML
@app.get("/")
async def get_index():
    return FileResponse('home.html')


# 2. Ton API de recherche
@app.get("/search")
def search(query: str = Query(...), k: int = 10):
    query_vector = model.encode([query],
                                normalize_embeddings=True).astype('float32')
    distances, indices = index.search(query_vector, k)

    results = data.iloc[indices[0]].copy()

    # On prépare les données pour le format attendu par ton HTML
    output = []
    for i, (idx, row) in enumerate(results.iterrows()):
        # Conversion en pourcentage
        score = int(distances[0][i] * 100)
        output.append({
            "title": row['track_name'],
            "artist": row['track_artist'],
            # Ou row['track_album_release_date'][:4] si dispo
            "year": "2024",
            "duration": "3:45",
            "score": score,
            # Initiale pour l'icône
            "art": row['track_name'][0],
            "color": "#B8865A",
            "textColor": "#FFF",
            "scoreClass": "high" if score > 70 else "mid"
        })
    return {"results": output, "tags": ["AI Optimized", "Semantic Match"]}
