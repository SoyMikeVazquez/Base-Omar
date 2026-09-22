-- Script para añadir la columna disponible_venta a la tabla Productos
ALTER TABLE "public"."Productos" ADD COLUMN IF NOT EXISTS "disponible_venta" boolean DEFAULT true NOT NULL;
