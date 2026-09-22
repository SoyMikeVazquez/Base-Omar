-- Script para añadir las columnas necesarias para cupones aplicables y contacto del proveedor a la tabla Productos
ALTER TABLE "public"."Productos" ADD COLUMN IF NOT EXISTS "cupones_aplicables" text[] DEFAULT '{}'::text[];
ALTER TABLE "public"."Productos" ADD COLUMN IF NOT EXISTS "contacto_proveedor" text;
