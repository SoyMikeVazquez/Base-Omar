-- Script para actualizar la base de datos en Supabase
-- Ejecuta este script en el SQL Editor de tu consola de Supabase.

-- 1. Modificaciones a la tabla "Proveedores" (Directorio de proveedores)
ALTER TABLE "public"."Proveedores"
  DROP COLUMN IF EXISTS "productos_ids",
  DROP COLUMN IF EXISTS "cantidad_habitual",
  DROP COLUMN IF EXISTS "precio_unitario",
  DROP COLUMN IF EXISTS "precio_total_pedid",
  DROP COLUMN IF EXISTS "lapso_pedido_dias";

-- 2. Modificaciones a la tabla "ProveedoresStock" (Pedidos y registros de stock)
-- Agregar las columnas requeridas para la gestión de pedidos
ALTER TABLE "public"."ProveedoresStock"
  ADD COLUMN IF NOT EXISTS "productos_pedidos" jsonb DEFAULT '[]'::jsonb NOT NULL,
  ADD COLUMN IF NOT EXISTS "deuda" double precision DEFAULT 0.0 NOT NULL,
  ADD COLUMN IF NOT EXISTS "completado" boolean DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS "url_factura" text,
  ADD COLUMN IF NOT EXISTS "meses_sin_intereses" integer DEFAULT 0 NOT NULL;

-- Hacer que las columnas individuales de producto sean opcionales/nullable (por compatibilidad)
ALTER TABLE "public"."ProveedoresStock"
  ALTER COLUMN "producto_id" DROP NOT NULL,
  ALTER COLUMN "cantidad" DROP NOT NULL,
  ALTER COLUMN "costo_unitario" DROP NOT NULL;

-- Eliminar columnas redundantes duplicadas de la tabla ProveedoresStock
ALTER TABLE "public"."ProveedoresStock"
  DROP COLUMN IF EXISTS "categoria",
  DROP COLUMN IF EXISTS "cantidad_habitual",
  DROP COLUMN IF EXISTS "precio_unitario",
  DROP COLUMN IF EXISTS "lapso_pedido_dias";
