-- Script para crear la tabla InventarioDiario con relación a Productos y restricción única por día
CREATE TABLE IF NOT EXISTS "public"."InventarioDiario" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "created_at" timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    "producto_id" uuid REFERENCES "public"."Productos"("id") ON DELETE CASCADE,
    "nombre_producto" text NOT NULL,
    "stock" int4 NOT NULL,
    "fecha" date NOT NULL,
    CONSTRAINT "unique_product_daily" UNIQUE ("producto_id", "fecha")
);
