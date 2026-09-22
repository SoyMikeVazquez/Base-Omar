import sys
import os
import json

# Auto-install firebase-admin if missing
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("El paquete 'firebase-admin' no está instalado. Instalándolo ahora...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "firebase-admin"])
    import firebase_admin
    from firebase_admin import credentials, firestore

def main():
    cred_file = "firebase_credentials.json"
    
    if not os.path.exists(cred_file):
        print(f"\n[ERROR] No se encontró el archivo '{cred_file}' en el directorio actual.")
        print("Por favor, descarga la clave privada JSON de tu cuenta de servicio desde la consola de Firebase:")
        print("1. Ve a la consola de Firebase (Configuración del Proyecto > Cuentas de servicio).")
        print("2. Haz clic en el botón 'Generar nueva clave privada'.")
        print("3. Guarda el archivo en esta carpeta con el nombre exacto: 'firebase_credentials.json'.")
        sys.exit(1)
        
    print("\nInicializando conexión con Firebase...")
    cred = credentials.Certificate(cred_file)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    print("\n¿Qué deseas exportar?")
    print("1. Una colección raíz (ej. 'users')")
    print("2. Una subcolección anidada de todos los usuarios (ej. 'citas', usando Collection Group)")
    
    opcion = input("Elige una opción (1 o 2): ").strip()
    
    if opcion == "1":
        col_name = input("Ingresa el nombre de la colección raíz (ej: users): ").strip()
        if not col_name:
            print("Nombre inválido.")
            return
            
        print(f"\nBuscando documentos en la colección raíz '{col_name}'...")
        docs = db.collection(col_name).stream()
        
        data = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data["id_documento"] = doc.id
            data.append(doc_data)
            
        file_out = f"export_{col_name}.json"
        with open(file_out, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4, default=str)
            
        print(f"\n[OK] ¡Éxito! Se exportaron {len(data)} documentos a '{file_out}'.")
        
    elif opcion == "2":
        sub_name = input("Ingresa el nombre de la subcolección anidada (ej: citas): ").strip()
        if not sub_name:
            print("Nombre inválido.")
            return
            
        print(f"\nBuscando subcolecciones '{sub_name}' (Collection Group)...")
        docs = db.collection_group(sub_name).stream()
        
        data = []
        for doc in docs:
            doc_data = doc.to_dict()
            doc_data["id_documento"] = doc.id
            # Extraer el ID del usuario padre de la ruta de referencia
            ref_path = doc.reference.path.split('/')
            if len(ref_path) >= 2:
                doc_data["id_usuario_padre"] = ref_path[1] # e.g. users/{userId}/citas/{citaId} -> ref_path[1] es userId
            data.append(doc_data)
            
        file_out = f"export_subcoleccion_{sub_name}.json"
        with open(file_out, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=4, default=str)
            
        print(f"\n[OK] ¡Éxito! Se exportaron {len(data)} documentos de la subcolección a '{file_out}'.")
    else:
        print("Opción inválida.")

if __name__ == "__main__":
    main()
