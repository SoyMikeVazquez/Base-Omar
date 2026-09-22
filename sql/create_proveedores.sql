-- Script para crear la tabla Proveedores con columna JSONB para asociar productos
CREATE TABLE IF NOT EXISTS "public"."Proveedores" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "created_at" timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    "nombre" text NOT NULL,
    "contacto" text,
    "productos_ids" jsonb DEFAULT '[]'::jsonb NOT NULL
);
