import os
# Crear carpeta de logs automáticamente ANTES de configurar el logging
os.makedirs("logs", exist_ok=True)

from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field, validator
from typing import Optional, List, Dict, Any
import pandas as pd
import numpy as np
import joblib
import json
import logging
from datetime import datetime
from contextlib import asynccontextmanager
import lightgbm as lgb
from fastapi.middleware.cors import CORSMiddleware
from sklearn.preprocessing import LabelEncoder
import traceback

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ModelManager:
    _instance = None
    _model = None
    _feature_encoder = None
    _target_encoder = None
    _features = None
    _loaded = False
    _error = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    @classmethod
    def load_model(cls, model_path: str = "modelo_lgbm_final.pkl", 
                   encoder_path: str = "mapeo_familias.json",
                   features_path: str = "features_config.json") -> bool:
        """Carga el modelo y sus dependencias de forma segura"""
        try:
            logger.info(f"Cargando modelo desde: {model_path}")
        
            required_files = [model_path, encoder_path, features_path]
            for f in required_files:
                if not os.path.exists(f):
                    raise FileNotFoundError(f"Archivo requerido no encontrado: {f}")
           
            cls._model = joblib.load(model_path)
            
            with open(encoder_path, 'r', encoding='utf-8') as f:
                cls._target_encoder = json.load(f)
            
            with open(features_path, 'r', encoding='utf-8') as f:
                config = json.load(f)
                cls._features = config['features']
                cls._feature_encoder = config.get('encoders', {})
            
            cls._loaded = True
            logger.info("✅ Modelo cargado exitosamente")
            return True
            
        except Exception as e:
            cls._error = str(e)
            logger.error(f"❌ Error cargando modelo: {e}")
            logger.error(traceback.format_exc())
            return False
    
    @classmethod
    def predict(cls, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Ejecuta predicción con validación y codificación automática de categóricos"""
        if not cls._loaded:
            raise RuntimeError("Modelo no cargado. Verificar logs.")
        
        try:
            logger.info(f"📥 Datos brutos recibidos: {input_data}")
            
            # Crear DataFrame con los datos de entrada
            df = pd.DataFrame([input_data])
            
            # Verificar campos faltantes
            missing = set(cls._features) - set(df.columns)
            if missing:
                raise ValueError(f"Features faltantes: {missing}")
            
            # ✅ CODIFICAR campos categóricos: convertir texto a índice numérico
            for col, encoder_info in cls._feature_encoder.items():
                if col in df.columns:
                    classes = encoder_info.get('classes', [])
                    # Crear mapeo: texto exacto -> índice
                    mapping = {str(v).strip(): i for i, v in enumerate(classes)}
                    logger.info(f"🔄 Mapeo para '{col}': {mapping}")
                    
                    # Obtener valor original para log
                    valor_original = df[col].iloc[0]
                    
                    # Mapear valores: si no encuentra coincidencia, usa -1
                    df[col] = df[col].astype(str).str.strip().map(lambda x: mapping.get(x, -1))
                    df[col] = df[col].fillna(-1).astype(int)
                    
                    logger.info(f"✅ Codificado: '{valor_original}' -> {df[col].iloc[0]}")
            
            # Rellenar valores numéricos faltantes (solo campos NO categóricos)
            for col in df.select_dtypes(include=[np.number]).columns:
                if col not in cls._feature_encoder:
                    df[col] = df[col].fillna(df[col].median() if df[col].notna().any() else 0)
            
            logger.info(f"📊 Datos procesados listos para el modelo")
            
            # Preparar array para el modelo (en el orden exacto de features)
            X = df[cls._features].values
            logger.info(f"🔢 Shape de features: {X.shape}")
           
            # Predicción con el modelo LightGBM
            pred_idx = cls._model.predict(X)[0]
            probas = cls._model.predict_proba(X)[0]
              
            # Decodificar el índice de la familia predicha
            familia_predicha = cls._target_encoder.get(str(int(pred_idx)), f"Cluster_{int(pred_idx)}")
            
            # Top 3 predicciones con sus probabilidades
            top_indices = np.argsort(probas)[-3:][::-1]
            top_predictions = [
                {
                    "familia": cls._target_encoder.get(str(int(i)), f"Cluster_{int(i)}"),
                    "probabilidad": float(probas[i]),
                    "cluster_id": int(i)
                }
                for i in top_indices
            ]
            
            return {
                "success": True,
                "prediction": {
                    "familia": familia_predicha,
                    "cluster_id": int(pred_idx),
                    "confianza": float(max(probas)),
                    "top_3": top_predictions
                },
                "timestamp": datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"❌ Error en predicción: {e}")
            logger.error(traceback.format_exc())
            raise

class PredictionInput(BaseModel):
    Altitud: float = Field(..., ge=-500, le=9000, description="Altitud en metros")
    Lat: float = Field(..., ge=-90, le=90, description="Latitud")
    Long: float = Field(..., ge=-180, le=180, description="Longitud")
    PAIS: str = Field(..., min_length=2, max_length=100, description="País")
    Tipo_Hoja: str = Field(..., description="Tipo de hoja")
    Textura_Suelo: str = Field(..., description="Textura del suelo")
    pH_Suelo: float = Field(..., ge=0, le=14, description="pH del suelo")
    Conductividad: float = Field(..., ge=0, description="Conductividad del suelo")
    Habitat: str = Field(..., description="Tipo de hábitat")
    Stem_dry_mass_per_stem_fresh_volume_stem_specific_density_SSD_wood_density_sapwood: Optional[float] = Field(
        default=None, ge=0, le=2, description="Densidad de madera"
    )
    
    @validator('PAIS', 'Tipo_Hoja', 'Textura_Suelo', 'Habitat', pre=True)
    def strip_strings(cls, v):
        return str(v).strip() if v else v

class PredictionResponse(BaseModel):
    success: bool
    prediction: Dict[str, Any]
    timestamp: str
    message: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    version: str
    timestamp: str

@asynccontextmanager
async def lifespan(app: FastAPI):
    success = ModelManager.load_model()
    if not success:
        logger.warning("⚠️ App iniciada sin modelo. Endpoint /predict no disponible.")
    yield
    logger.info("🔚 Cerrando aplicación...")

app = FastAPI(
    title="API Botánica - Clasificador de Familias",
    description="Servicio de predicción de familias botánicas usando LightGBM",
    version="1.0.0",
    lifespan=lifespan
)

# ✅ Configurar CORS para permitir conexiones desde Flutter/Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todos los orígenes (para desarrollo)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos los métodos HTTP
    allow_headers=["*"],  # Permite todos los headers
)

@app.get("/", response_model=Dict[str, str])
async def root():
    return {
        "message": "API Botánica - Clasificador de Familias",
        "docs": "/docs",
        "health": "/health",
        "predict": "/predict (POST)"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="healthy" if ModelManager._loaded else "degraded",
        model_loaded=ModelManager._loaded,
        version="1.0.0",
        timestamp=datetime.now().isoformat()
    )

@app.post("/predict", response_model=PredictionResponse)
async def predict_familia(data: PredictionInput):
    try:
        # ✅ DEBUG: Ver qué datos recibe el backend
        logger.info(f"📥 Datos recibidos: {data.dict()}")
        
        if not ModelManager._loaded:
            raise HTTPException(
                status_code=503,
                detail="Servicio de predicción no disponible. Modelo no cargado."
            )
        
        input_dict = data.dict(exclude_unset=True)
        result = ModelManager.predict(input_dict)
        
        logger.info(f"✅ Predicción exitosa: {result['prediction']['familia']}")
        return PredictionResponse(**result, message="Predicción completada")
        
    except ValueError as e:
        logger.warning(f"❌ Error de validación: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        logger.error(f"❌ Error de servicio: {e}")
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        logger.error(f"❌ Error inesperado: {e}")
        raise HTTPException(status_code=500, detail="Error interno del servidor")

@app.get("/features")
async def get_features():
    if not ModelManager._loaded:
        return {"error": "Modelo no cargado"}
    
    return {
        "required_features": ModelManager._features,
        "categorical_features": list(ModelManager._feature_encoder.keys()),
        "numeric_features": [f for f in ModelManager._features if f not in ModelManager._feature_encoder]
    }

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Error no manejado en {request.url}: {exc}")
    return {
        "success": False,
        "error": "Error interno del servidor",
        "detail": str(exc) if app.debug else "Consulta los logs para más detalles"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 8000)),
        reload=False,  
        log_level="info"
    )