-- Script para crear la tabla EmpresasEntrenadores
DROP TABLE IF EXISTS "public"."EmpresasEntrenadores" CASCADE;

CREATE TABLE IF NOT EXISTS "public"."EmpresasEntrenadores" (
    "IDEmpresa" text PRIMARY KEY,
    "created_at" timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    "nombre" text NOT NULL,
    "correo_electronico" text NOT NULL,
    "telefono" numeric,
    "foto perfil" text,
    "numero_clientes" integer DEFAULT 0 NOT NULL,
    "fecha_corte" date,
    "calificacion" double precision DEFAULT 0.0 NOT NULL,
    "reseñas" jsonb DEFAULT '[]'::jsonb NOT NULL,
    "inhabilitado" boolean DEFAULT false NOT NULL,
    "userID" uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL UNIQUE
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE "public"."EmpresasEntrenadores" ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad de Supabase
CREATE POLICY "Permitir lectura publica de EmpresasEntrenadores" ON "public"."EmpresasEntrenadores"
    FOR SELECT USING (true);

CREATE POLICY "Permitir gestion total de EmpresasEntrenadores a autenticados" ON "public"."EmpresasEntrenadores"
    FOR ALL USING (
        auth.uid() IS NOT NULL
    );
