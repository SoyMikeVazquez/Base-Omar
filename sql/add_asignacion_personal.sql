-- Script para agregar la columna asignacion_personal a la tabla InventarioDiario
ALTER TABLE "public"."InventarioDiario" ADD COLUMN IF NOT EXISTS "asignacion_personal" jsonb DEFAULT '[]'::jsonb NOT NULL;
