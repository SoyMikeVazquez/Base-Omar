-- Script para añadir columna de porcentaje de venta del personal a la tabla Productos
ALTER TABLE "public"."Productos" ADD COLUMN IF NOT EXISTS "porcentaje_venta_personal" numeric DEFAULT 0;
