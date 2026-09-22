-- Script para crear la tabla ProveedoresStock con relación a Productos
CREATE TABLE IF NOT EXISTS "public"."ProveedoresStock" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "created_at" timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    "producto_id" uuid REFERENCES "public"."Productos"("id") ON DELETE CASCADE,
    "proveedor" text NOT NULL,
    "cantidad" int4 NOT NULL,
    "costo_unitario" numeric DEFAULT 0.0 NOT NULL,
    "fecha" date NOT NULL
);
