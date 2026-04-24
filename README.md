

# 🎵 Semantic Music Search Engine (NLP)

## 📝 Description
Ce projet est un moteur de recherche de musique "intelligent" basé sur le **Traitement du Langage Naturel (NLP)**. Contrairement aux moteurs de recherche classiques qui se limitent à des mots-clés exacts (titre ou artiste), ce système comprend l'**intention sémantique** derrière une requête.

Grâce aux **Embeddings**, l'utilisateur peut rechercher des chansons par :
* **Émotions** (ex: "quelque chose pour une rupture amoureuse")
* **Concepts** (ex: "voyage dans l'espace et les étoiles")
* **Descriptions de scènes** (ex: "ambiance pour rouler de nuit sous la pluie")

Le système croise ensuite ces résultats sémantiques avec les données acoustiques (valence, énergie, danceability) pour affiner la pertinence.

---

## ⚙️ Fonctionnement Technique

Le projet repose sur un pipeline de données en trois étapes majeures :

### 1. Vectorisation (Embeddings)
Nous utilisons le modèle `paraphrase-multilingual-MiniLM-L12-v2`. Chaque morceau est transformé en un vecteur de **384 dimensions** représentant son sens textuel global (Artiste + Titre + Album + Paroles).

### 2. Indexation Vectorielle (FAISS)
Pour garantir une recherche en millisecondes parmi des milliers de titres, nous utilisons **FAISS** (Facebook AI Similarity Search). Les vecteurs sont indexés dans un espace multidimensionnel où la proximité mathématique correspond à la proximité de sens.

### 3. Recherche Hybride & API
Le backend est propulsé par **FastAPI**. Lorsqu'une requête arrive :
1.  La requête est convertie en vecteur.
2.  FAISS identifie les $k$ voisins les plus proches.
3.  (Optionnel) Un re-ranking est appliqué en fonction de la popularité ou des attributs audio.

---

## 🚀 Installation et Lancement

### Prérequis
* Python 3.8+
* Le fichier de données `spotify_songs.csv`

### 1. Clonage et Dépendances
```bash
git clone https://github.com/Gionnah/lyrx.git
cd lyrix
pip install -r requirements.txt
```

### 2. Préparation des données
Avant de lancer le serveur, vous devez générer la "mémoire" vectorielle (cela peut prendre quelques minutes selon votre CPU) :
```bash
python scripts/generate_embeddings.py
```
*Ceci créera le fichier `music_embeddings.npy`.*

### 3. Lancement de l'API
```bash
uvicorn main:app --reload
```
L'API sera disponible sur : `http://127.0.0.1:8000`

---

## 🛠️ Utilisation (Endpoints API)

### Recherche Sémantique
**Endpoint :** `GET /search`

| Paramètre | Type | Description |
| :--- | :--- | :--- |
| `query` | string | Votre recherche en langage naturel. |
| `k` | int | Nombre de résultats souhaités (par défaut 5). |

**Exemple de requête :**
`http://127.0.0.1:8000/search?query=happy+songs+for+summer&k=3`

**Exemple de réponse JSON :**
```json
[
  {
    "track_name": "Walking On Sunshine",
    "track_artist": "Katrina & The Waves",
    "playlist_genre": "pop",
    "score": 0.89
  },
  ...
]
```

---

## 📊 Évaluation du Projet
Pour valider l'efficacité du moteur, nous utilisons les critères suivants :
* **Précision sémantique :** Capacité du modèle à lier des synonymes (ex: "sad" et "melancholic").
* **Vitesse de réponse :** Temps de recherche inférieur à 200ms grâce à l'indexation FAISS.
* **Robustesse multilingue :** Capacité à trouver des titres anglais via des requêtes en français.

---

> **Note :** Ce projet a été réalisé dans le cadre d'une exploration des technologies NLP et de la recherche vectorielle.

---

### Structure des fichiers recommandée
```text
.
├── main.py              # Serveur FastAPI
├── requirements.txt     # Dépendances
├── data/
│   └── music_data.csv   # Dataset original
├── models/
│   └── music_embeddings.npy # Vecteurs générés
└── scripts/
    └── preprocess.py    # Nettoyage et vectorisation
```